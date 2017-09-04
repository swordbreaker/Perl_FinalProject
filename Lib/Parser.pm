package Parser;

use v5.26;
use strict;
use experimental 'signatures';

use Exporter 'import';
our @EXPORT  = qw(parse sortKeys);

use ParserMover qw(init consumeLine peekLine isEmpty length getFileLine);

=head1 Parser
    This module parses a file and returns information about the questions and answers.
=cut

my $separatorRegex = qr/^\s* _+ \s*$ | ^\s* =+ \s*$ /x;
my $questionRegex = qr/.* (\d+ .*)/x;
my $multipleChoiceRegex = qr/^\s* \[(.*?)\](.+)$/x;
my $emptyLineRegex = qr/^\s*$/;
my $separator;
my $fileName;

=item parse($file)
    Parses a file.

    Input: 
        $file: the path to the file to parse
    Output
        ($introText:string, $separator:string, %questions)
        $introText: returns a string of the text before the questions without a separator
        $separator: returns the first parsed separator most likely a line with _
        %question: a hash which looks as follows
            "questionA" =>          the question parsed. (Can be multiple lines with \n in it)
            [
                ["answerA", 1],     The answers to the question as the first element and
                ["answerB", ""]     a boolean if the answer was checked as the second element of the array.
            ]
=cut
sub parse($file)
{
    $fileName = $file;
    open(my $fileHandle, "<", $file) or die "Can't open < $file: $!";
    my @lines = readline $fileHandle;
    ParserMover::init(@lines);
    my $introText = parseIntro();
    my %questions = parseQuestions();
    close($fileHandle);
    return ($introText, $separator, %questions);
}

=item parseIntro()
    Parses the intro text.

    Output: returns a string with the intro text in it can be a multi line string.
=cut
sub parseIntro()
{
    my $line = ParserMover::consumeLine();
    
    #parse till a line matches the separator regex.
    if($line =~ m/$separatorRegex/)
    {
        $separator = $line;
        return "";
    }
    else
    {
        my $introText = $line;
        return $introText . parseIntro();
    }
}

=item parseQuestions()
    Parses the questions.

    Output: returns a Hash which is describe in the parse() subrutine.
=cut
sub parseQuestions()
{
    my %questions; # {questionA => [ [answerX, 1], [answerY, ""] ], ...}
    
    skipEmptyLines();
    die createErrorMessage('Error file needs to end with a separator') if ParserMover::isEmpty();

    #parse as long as the next line matches the question pattern
    while(ParserMover::peekLine() =~ m/$questionRegex/)
    {
        #parse the question
        my $question = parseQuestionBlock();
        #parse the answers
        my @answers = parseMultipleChoice();

        $questions{$question} = \@answers;

        skip($separatorRegex);
        skipEmptyLines();

        #if there are no more line to parse exit the while loop
        last if ParserMover::isEmpty();
    }

    return %questions;
}

=item parseQuestionBlock()
    Parses a question on multiple lines till an empty line is consumed.

    Output: returns a string with the question (can be multi line)
=cut
sub parseQuestionBlock()
{
    my $line = ParserMover::consumeLine();

    #parse till the line matches with the empty line regex.
    if($line =~ m/$emptyLineRegex/)
    {
        return "";
    }
    else 
    {
        return $line . parseQuestionBlock();
    }
}

=item parseMultipleChoice()
    Parses a answer.

    Output: returns an array which contains the answer as first element and an boolean if its checked as second element.
=cut
sub parseMultipleChoice()
{
    #skip empty lines
    skipEmptyLines() if !ParserMover::isEmpty();
    die createErrorMessage('Error file needs to end with a separator') if ParserMover::isEmpty();

    my $line = ParserMover::consumeLine();
    
    #parse till a line matches with the separator pattern
    if($line =~ m/$separatorRegex/)
    {
        return ();
    }
    else
    {
        $line =~ m/$multipleChoiceRegex/ or die createErrorMessage('Parse error cannot parse line as a multiple choice');
        my $x = $1;
        my $question = $2;

        $question ne "" || !defined $question 
            or die Parser::createErrorMessage('Parse error the answer is empty');

        return ([$question, isCrossed($x)], parseMultipleChoice());
    }
}

=item isCrossed($str)
    Checks if an x or X is set in the checkbox []

    Input: 
        $str:string the string inside the checkbox (without the brackets [])
=cut
sub isCrossed($str)
{
    return lc(trim($str)) eq "x";
}

=item skipEmptyLines()
    Consumes all empty (only white space character) lines till the next line is not an empty line.
=cut
sub skipEmptyLines()
{
    skip($emptyLineRegex);
}

=item skip($regex)
    Tires to parse the regex on the current line if it matches it consumes the line. 
    Repeats the behavior till the regex does not match.

    Input: 
        $regex:string a regex to math
=cut
sub skip($regex)
{
    while(!ParserMover::isEmpty() && ParserMover::peekLine() =~ m/$regex/)
    {
        ParserMover::consumeLine();
    }
}

=item createErrorMessage($msg)
    Appends the filename and file line to a string.

    Input: 
        $msg:string A string of the error message
    Output: 
        A string with the information about filename and file line appended.
=cut
sub createErrorMessage($msg)
{
    return "$msg in file $fileName at line " . ParserMover::getFileLine();
}

=item trim($value)
    Removes whitespace at the start and end of a string

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

=item sortKeys(%questions)
    Sort the questions key after their number.

    Input: 
        %questions: Hash produced by the parse subroutine

    Output
        @list:@strings: A list of sorted questions.
=cut
sub sortKeys(%questions)
{
    my @list = sort { getNumberFormQuestion($a) <=> getNumberFormQuestion($b) } (keys %questions);
    return @list;
}

=item getNumberFormQuestion($question)
    Search for a Number in a string

    Input: 
        $question:string

    Output
        int the first found number.
=cut
sub getNumberFormQuestion($question)
{
    $question =~ m/.*? (\d+) .*?/x;
    return $1;
}

1;
# end of module