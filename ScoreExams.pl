use v5.26;
use strict;
use experimental 'signatures';

use FindBin;
use lib "$FindBin::Bin/Lib";

use Stopwords qw(saveToFile);
use Parser qw(parse sortKeys);
use Writer qw(saveToFile);
use Statistics qw(printStats);
use MisconductDetector qw(identifyingPossibleAcademicMisconduct);

use Time::Moment;
use File::Basename;
use Text::Levenshtein qw(distance);
use List::Util qw(min);

=head1 ScoreExams
    Used to Score the exams and return useful information about them.

    Usage: perl ScoreExam.pl [master_file_path] [studentFiles]
        [master_file_path] the path to the master file
        [studentFiles] A list of student files. Supports file pattern like *-short_exam_master_*.txt

    Example: perl ScoreExams.pl AssignmentDataFiles/MasterFiles/FHNW_entrance_exam_master_file.txt AssignmentDataFiles/SampleResponses/*
             perl ScoreExams.pl AssignmentDataFiles/MasterFiles/FHNW_entrance_exam_master_file.txt *-short_exam_master_*.txt
=cut

use constant EDIT_THRESHOLD => 0.1;

main(@ARGV);

=item main(@args)
    The main method of the script.

    Input: 
        @args:@mixed the command line arguments
=cut
sub main(@args)
{
    scalar(@args) >= 2 or die "You need to provide at least 2 argument the masterfile and n students files";

    #todo support regex files
    my ($masterFile, @filePatterns) = @args;
    my @studentsFiles;

    -e $masterFile or die "File $masterFile not found";

    foreach my $filePattern (@filePatterns)
    {
        foreach my $file (glob($filePattern))
        {
            -e $file or die "File $file not found";
            push @studentsFiles, $file;
        }
    }

    scalar(@studentsFiles) > 0 or die "no files found with the given pattern"; 

    my @statistics; # [{score => 0, answeredQuestions => 0, file => "", answerBinaryMatrix => 0}]

    (my $a, my $b, my %questionsMaster) = Parser::parse($masterFile);
    foreach my $file (@studentsFiles)
    {
        my %stats = compareFiles($file, %questionsMaster);
        push @statistics, \%stats;
    }

    my $total = %questionsMaster;
    Statistics::printStats($total, @statistics);
    MisconductDetector::identifyingPossibleAcademicMisconduct(\@statistics, scalar %questionsMaster);
}

=item compareFiles(%questionsCorrect, $studentFile)
    Compares 2 files and prints out the score reached. It will also gather statistic data.

    Input:
        $studentFile:string path to the students file
        %questionsCorrect: a hash which looks as follows
            "questionA" =>          the question parsed. (Can be multiple lines with \n in it)
            [
                ["answerA", 1],     The answers to the question as the first element and
                ["answerB", ""]     a boolean if the answer was checked as the second element of the array.
            ]

    Output: (score => int, answeredQuestions => int, file => string)
        score: the reached score.
        answeredQuestions: How many question where answered. (Will also count question which have more than one answer marked)
        file: the file name.
=cut
sub compareFiles($studentFile, %questionsMaster)
{
    (my $a, my $b, my %questionsStudent) = Parser::parse($studentFile);

    my @errors;
    my $score = 0;
    my $answeredQuestions = 0;
    my @answerBinaryMatrix;

    #todo sort hash
    foreach my $question (Parser::sortKeys(%questionsMaster))
    {
        my $correctOptionRef = %questionsMaster{$question};
        my $usedQuestion = undef;

        #set usedQuestion when if the question exists in the student hash
        $usedQuestion = $question if(exists $questionsStudent{$question});

        #search for a identical question when question does not exists in the student hash
        $usedQuestion = searchForIdenticalQuestion($question, \@errors, %questionsStudent)
            if !defined($usedQuestion);

        #if there was no identical match try to find a similar question
        $usedQuestion = searchForSimilarQuestion($question, \@errors, %questionsStudent)
            if !defined($usedQuestion);

        #if there is no similar question go to the next element
        if(!defined($usedQuestion))
        {
            push @errors, 'Missing question ' . betterChomp($question);
            push @errors, 'No similar question found :(';
            next;
        }

        #check if student selected correct answer and if he has check a box
        (my $correct, my $answered, my $answerBinaryTable) = compareAnswers($correctOptionRef, $questionsStudent{$usedQuestion}, \@errors);

        push @answerBinaryMatrix, $answerBinaryTable;
        $score++ if $correct;
        $answeredQuestions++ if $answered;
    }

    #output the score of the student
    my $total = %questionsMaster;
    say basename($studentFile) . "\t $score / $total";
    say (map {"\t" . $_ . "\n"} @errors);

    return (score => $score, answeredQuestions => $answeredQuestions, file => basename($studentFile), answerBinaryMatrix => \@answerBinaryMatrix);
}

=item searchForIdenticalQuestion($question, $errorRef, %questionsStudent)
    Searches for a Identical question in the questionStudent hash.

    Input:
        $question:string text of the question
        $errorRef:\@string an reference to the error array to store encounters errors
        %questionsStudent: a hash which looks as follows
            "questionA" =>          the question parsed. (Can be multiple lines with \n in it)
            [
                ["answerA", 1],     The answers to the question as the first element and
                ["answerB", ""]     a boolean if the answer was checked as the second element of the array.
            ]

        Output: 
            $usedQuestion:string returns the key of the questionsStudent hash on success else returns undef
=cut
sub searchForIdenticalQuestion($question, $errorRef, %questionsStudent)
{
    my $usedQuestion = undef;
    my @foundQuestions = grep { trim(lc($_)) eq trim(lc($question)) } keys %questionsStudent;

    scalar(@foundQuestions) <= 1 or push $errorRef->@*, "Multiple identical questions @foundQuestions" if(scalar @foundQuestions > 1);

    $usedQuestion = $foundQuestions[0] if(scalar @foundQuestions >= 1);
    return $usedQuestion;
}

=item searchForSimilarQuestion($question, $errorRef, %questionsStudent)
    Compares the question with the edit distance and tries to find a similar question.

    Input:
        $question:string text of the question
        $errorRef:\@string an reference to the error array to store encounters errors
        %questionsStudent: a hash which looks as follows
            "questionA" =>          the question parsed. (Can be multiple lines with \n in it)
            [
                ["answerA", 1],     The answers to the question as the first element and
                ["answerB", ""]     a boolean if the answer was checked as the second element of the array.
            ]

        Output: 
            $usedQuestion:string returns the key of the questionsStudent hash on success else returns undef
=cut
sub searchForSimilarQuestion($question, $errorRef, %questionsStudent)
{
    my $usedQuestion = undef;
    my @questionsStudents = keys %questionsStudent;
    my @dist = distance(normalize($question), normalizeList(@questionsStudents));

    (my $min, my $idx) = findMin(@dist);

    if ($min/length($question) < EDIT_THRESHOLD)
    {
        $usedQuestion = $questionsStudents[$idx];

        push $errorRef->@*, 'Missing question: ' . betterChomp($question);
        push $errorRef->@*, 'Used this instead: ' . betterChomp($usedQuestion);
    }
    return $usedQuestion;
}

=item compareAnswers($optionsMasterRef, $optionsStudentRef, $errorsRef)
    Compares two options to find out the question was answered right, and if it was answered.

    Input: 
        $optionsMasterRef: An array reference in the format:
        [
            [string, bool],  first element represents the answer text and the second if it was marked wit an x.
            ...
        ]
        $optionsStudentRef: same as $optionsMasterRef
        $errorRef:\@string array reference to store error messages in it.

    Output: ($correct, $wasAnswered, $answerBinaryTable)
        $correct:bool was the question answered correctly
        $wasAnswered: was an answerer of the question selected
        $answerBinaryTable:int 
            where the answer integer must be interpreted as an bit.
            
            answer1 selected  answer2 selected  correct answered
            0                 1                 1               

            This makes it possible to compare the 2 ints and check if the correct answer was selected (even).
=cut
sub compareAnswers($optionsMasterRef, $optionsStudentRef, $errorsRef)
{
    #normalize the answers
    my @optionsMaster = $optionsMasterRef->@*;
    my @optionsStudent = $optionsStudentRef->@*;

    my $marked = 0;
    my $selectedRight = 0;
    my $answerBinaryTable = 0b0;
    
    #foreach answer in the master question
    for(my $i = 0; $i < scalar(@optionsMaster); ++$i)
    {
        $a = @optionsMaster[$i];

        #create an array with all normalized answer strings.
        my @b = map { $_->[0] } @optionsStudent;

        #search for an Identical answer in the @b array
        my $idx = searchForIdenticalAnswer($a->[0], \@b, $errorsRef);

        #search for an similar answer int the @b array
        $idx = searchForSimilarAnswer($a->[0], \@b, $errorsRef) if !defined($idx);

        #if there was no match then save an error message an go to the next entry.
        if(!defined($idx))
        {
            push $errorsRef->@*, 'Missing answer: '. betterChomp($a->[0]);
            push $errorsRef->@*, 'No similar answer found :(';
            next;
        }

        #was the answer selected
        if ($optionsStudent[$idx]->[1])
        {
            $marked++ if $optionsStudent[$idx]->[1];
            #add a 1 to the binary number at the location answer Index + 1
            $answerBinaryTable |= (1 << $i+1);
        }

        #if the answer was selected and the answer is right
        if($optionsStudent[$idx]->[1] && $a->[1])
        {
            $selectedRight = 1;
        }   
    }

    #only count it as correct when only one answer was selected.
    my $correct = $marked == 1 && $selectedRight;
    $answerBinaryTable |= 1 if($correct);

    return ($correct, $marked > 0, $answerBinaryTable);
}

=item searchForIdenticalAnswer ($searchedAnswer, $optionTextStudentRef, $errorsRef)
    Searches for an identical match in the answers of the student.

    Input:
        $searchedAnswer:string the answer which should be searched
        $optionTextStudentRef:@string an array ref which contains all available answer of the student file.
        $errorRef:\@string array reference to store error messages in it.

    Output;
        If found the index in the $optionTextStudentRef else undef

=cut
sub searchForIdenticalAnswer ($searchedAnswer, $optionTextStudentRef, $errorsRef)
{
    my $idx = undef;
    my @optionTexts = @{$optionTextStudentRef};

    #get the index of all identical matches 
    my @idx = grep { fc(trim($optionTexts[$_])) eq fc(trim($searchedAnswer))} 0..$#optionTexts;
    $idx = @idx[0] if scalar(@idx) > 0;

    #when there are more than one identical match
    push $errorsRef->@*, "Multiple identical answers: @optionTexts[@idx]" if scalar(@idx) > 1;

    return $idx;
}

=item searchForSimilarAnswer($searchedAnswer, $optionTextStudentRef, $errorsRef)
    Searches for an similar match in the answers of the student with the levenstein distance.

    Input:
        $searchedAnswer:string the answer which should be searched
        $optionTextStudentRef:@string an array ref which contains all available answer of the student file.
        $errorRef:\@string array reference to store error messages in it.

    Output;
        If found the index in the $optionTextStudentRef else undef

=cut
sub searchForSimilarAnswer($searchedAnswer, $optionTextStudentRef, $errorsRef)
{
    #normalize all strings
    my @optionTexts = normalizeList(@{$optionTextStudentRef});
    my $searchedAnswerNormalized = normalize($searchedAnswer);

    #calculate the distance form searchedAnswerNormalized to all strings in @optionTexts
    my @dist = distance($searchedAnswerNormalized, @optionTexts);
    (my $min, my $idx) = findMin(@dist);

    if($min/length($searchedAnswerNormalized) < EDIT_THRESHOLD && $min != 0)
    { 
        push $errorsRef->@*, 'Missing answer: ' . betterChomp($searchedAnswer);
        push $errorsRef->@*, 'Used this instead: ' . betterChomp($optionTextStudentRef->[$idx]);
    }
    else 
    {
        $idx = undef;
    }

    return $idx;
}

=item findMin(@list)
    Find the min value in a array.

    Input:
        @list:@number a array of values.

    Output: ($min, $idx)
        $min:number the min value.
        $idx:int the index where the min value was found.

    Note: if there are more than one min value it takes the first one found.
=cut
sub findMin(@list)
{
    my $min = undef;
    my $idx = undef;
    for(my $i = 0; $i < scalar @list; ++$i)
    {
        if(!defined($min) || $min > $list[$i])
        {
             $min = $list[$i];
             $idx = $i;
        }
    }
    return ($min, $idx);
}

=item normalizeList(@list)
    Normalize all entries in a list

    Input:
        @list:string

    Output:
        @list:string a list with all entries normalized.
=cut
sub normalizeList(@list)
{
    foreach my $value (@list)
    {
        $value = normalize($value);
    }

    return @list;
}

=item normalize($value)
    Normalizes a value (to lower case, remove stopwords, replace all whitespace with a single space, trim).

    Input:
        $value:string

    Output:
        A normalized string.
=cut
sub normalize($value)
{
    $value = fc $value;

    foreach my $stopword (Stopwords::getStopwords())
    {
        $value =~ s/\s $stopword \s/ /x;
    }

    $value =~ s/\s+/ /;
    $value = trim($value);
    return $value;
}

=item betterChomp($value)
    Same as chomp but int returns the chomp value.

    Input:
        $value: string

    Output:
        string
=cut 
sub betterChomp($value)
{
    chomp($value);
    return $value;
}

=item trim($value)
    Removes whitspace at the start and end of a string

    Input:
        $value:string

    Output:
        string
=cut 
sub trim($value)
{
    $value =~ s/^\s+|\s+$//g;
    return $value;
}