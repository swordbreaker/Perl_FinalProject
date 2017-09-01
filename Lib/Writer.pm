package Writer;

use v5.26;
use strict;
use experimental 'signatures';

use Exporter 'import';
our @EXPORT  = qw(saveToFile debugSaveRandomFilled);

use List::Util qw(shuffle);

=head1 Writer
    This module writes the parsed information to a file.
=cut

=item saveToFile($file, $intro, $separator, %questions)
    Save the parsed information to a file and shuffles the answers.

    Input: 
        $file:string the filename
        $intro:string the intro text
        $separator:string the separator
        %question: a hash which looks as follows
            "questionA" =>          the question parsed. (Can be multiple lines with \n in it)
            [
                ["answerA", 1],     The answers to the question as the first element and
                ["answerB", ""]     a boolean if the answer was checked as the second element of the array.
            ]
=cut
sub saveToFile($file, $intro, $separator, %questions)
{
    open(my $fileHandle, ">", $file) or die "Can't open < $file: $!";

    print $fileHandle $intro;
    print $fileHandle $separator;

    foreach my $question (sort keys %questions)
    {
        my $options = $questions{$question};
        say $fileHandle "";
        print $fileHandle $question;
        say $fileHandle "";

        foreach my $option (shuffle $options->@*)
        {
            say $fileHandle "\t [ ]" . $option->[0];
        }

        say $fileHandle "";
        print $fileHandle $separator;
    }

    close($fileHandle);
}

=item
    Does the same as saveToFile but answers the question randomly.
=cut
sub debugSaveRandomFilled($file, $intro, $separator, %questions)
{
    open(my $fileHandle, ">", $file) or die "Can't open < $file: $!";

    print $fileHandle $intro;
    print $fileHandle $separator;

    foreach my $question (sort keys %questions)
    {
        my $options = $questions{$question};
        say $fileHandle "";
        print $fileHandle $question;
        say $fileHandle "";

        my @randomValues = shuffle ('X', (' ') x $#{ $options });

        my $i = 0;
        foreach my $option (shuffle $options->@*)
        {
            my $v = @randomValues[$i];
            say $fileHandle "\t [$v]" . $option->[0];
            $i++;
        }

        say $fileHandle "";
        print $fileHandle $separator;
    }

    close($fileHandle);
}

1;
# end of module