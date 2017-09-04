package MisconductDetector;

use v5.26;
use strict;
use experimental 'signatures';

use Exporter 'import';
our @EXPORT  = qw(identifyingPossibleAcademicMisconduct);

use constant SAME_WRONG_THRESHOLD => 0.5;
use constant SAME_WRIGHT_THRESHOLD => 0.5;

=head1 MisconductDetector
    This module tries to detect possible academic misconduct
=cut

=item identifyingPossibleAcademicMisconduct($statisticsRef, $maxQuestions)
    Identifies possible academic miscount and prints it out to the console.

    Input: 
        $statisticsRef: statistics array reference in the format:
        [
            {score => int, answeredQuestions=> int, file => string, answerBinaryMatrix => \@int},
            ...
        ]
        $maxQuestions:int the amount of questions
=cut
sub identifyingPossibleAcademicMisconduct($statisticsRef, $maxQuestions)
{
    my @statistics = @{$statisticsRef};

    my $length = @statistics;

    say "";
    say "Similar patterns of answers:";
    
    #go throw every combination once (when a <=> b we dont need to compare b <=> a)
    for(my $i = 0; $i < $length - 1; $i++)
    {
        my $statsARef = $statistics[$i];
        my $binMatrixARef = $statsARef->{'answerBinaryMatrix'};

        for(my $k = $i+1; $k < $length; $k++)
        {
            my $statsBRef = $statistics[$k];

            #we dont need to compare the same element
            next if $i == $k;
            #When one has everything right. We don't need to compare the files.
            next if $statsARef->{'score'} == $maxQuestions || $statsBRef->{'score'} == $maxQuestions;

            my $binMatrixBRef = $statsBRef->{'answerBinaryMatrix'};
            my %data = compare($binMatrixARef, $binMatrixBRef);
            
            if($data{'sameWrongPercentage'} > SAME_WRONG_THRESHOLD && $data{'sameRightPercentage'} > SAME_WRIGHT_THRESHOLD)
            {
                my $minScore = min($statsARef->{'score'}, $statsBRef->{'score'});
                my $probability = $data{'samePercentage'} * (1 - ($minScore/$maxQuestions*0.6));

                say "    " . $statsARef->{'file'} . " (score: $statsARef->{'score'})";
                say 'and ' . $statsBRef->{'file'} . " (score: $statsBRef->{'score'}) \t probability $probability";
                say "Questions which were answered the same:\t\t" . toPercent($data{'samePercentage'});
                say "Wrong answers which were answered the same:\t" . toPercent($data{'sameWrongPercentage'});
                say "Right answers which were answered the same:\t" . toPercent($data{'sameRightPercentage'});
                say "";
            }
        }
    }
}

=item compare($matrixA, $matrixB)
    Compares 2 binaryAnswerMatrixes and returns information about how similar the two are.

    Input:
        $matrixA:@array, $matrixB:@array in form of
            [answer1, answer2, ...]
            where the answer integer must be interpreted as an bit.
            
            answer1 selected  answer2 selected  correct answered
            0                 1                 1               

            This makes it possible to compare the 2 ints and check if the correct answer was selected (even).

    Output:
        %data:hash
            (
                sameRightPercentage => int,     same answer given and wrong answer / min (a answered wrong, b answered wrong)
                sameWrongPercentage => int,     same answer given and right answer / min (a answered right, b answered right)
                samePercentage => int           how mans answer were answer the same / answer count
            )
=cut
sub compare($matrixA, $matrixB)
{
    my %data = 
    (
        sameRightPercentage => 0,
        sameWrongPercentage => 0,
        samePercentage => 0
    );

    my ($sameRightCount, $sameWrongCount, $sameCount) = 0;
    my ($aWrongCount, $bWrongCount, $aRightCount, $bRightCount) = 0;

    my $length = @{$matrixA};

    for(my $i = 0; $i < $length; $i++)
    {
        $a = $matrixA->[$i];
        $b = $matrixB->[$i];

        #is the question answered the same
        if($a == $b)
        {
            $sameCount++;

            #check if question is answered correctly.
            (($a | 1) == $a) ? $sameRightCount++ : $sameWrongCount++;
        }

        #check if a/b have answered the question right
        (($a | 1) == $a) ? $aRightCount++ : $aWrongCount++;
        (($b | 1) == $b) ? $bRightCount++ : $bWrongCount++;
    }
    
    #check for 0 to prevent div by 0 exception
    my $aWrongPercentage = ($aWrongCount != 0)
        ? $sameWrongCount / $aWrongCount
        : 0;

    my $bWrongPercentage = ($bWrongCount != 0)
        ? $sameWrongCount / $bWrongCount
        : 0;

    $data{sameWrongPercentage} = min($aWrongPercentage, $bWrongPercentage);

    my $aRightPercentage = ($aRightCount != 0)
        ? $sameRightCount / $aRightCount
        : 0;

    my $bRightPercentage = ($bRightCount != 0)
        ? $sameRightCount / $bRightCount
        : 0;

    $data{sameRightPercentage} = min($aRightPercentage, $bRightPercentage);

    $data{samePercentage} = $sameCount / $length;

    return %data;
}

=item min($a, $b)
    Returns the minimum between two numbers

    Input:
        a:number
        b:number

    Output:
        number the minimum.
=cut
sub min($a, $b)
{
    return ($a < $b) ? $a : $b; 
}

=item toPercent($value)
    Returns a percentage formated string.

    Input:
        $value:int

    Output:
        string in the format ($value*100)%
=cut
sub toPercent($value)
{
    return sprintf("%2d%%", $value*100)
}

1;
# end of module