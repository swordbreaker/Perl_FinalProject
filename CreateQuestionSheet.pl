use v5.26;
use strict;
use experimental 'signatures';

use FindBin;
use lib "$FindBin::Bin/Lib";

use Parser;
use Writer qw(saveToFile debugSaveRandomFilled);
use Time::Moment;
use File::Basename;

=head1 CreateQuestionSheet
    Used to create a question sheet from a master file.

    Usage: perl CreateQuestionSheet.pl [master_file_path] [debug]
        [master_file_path] the path to the master file
        [debug] optional flag. When set then the created sheet will be answered randomly.

    Example: perl CreateQuestionSheet.pl AssignmentDataFiles\MasterFiles\FHNW_entrance_exam_master_file.txt
                perl CreateQuestionSheet.pl AssignmentDataFiles\MasterFiles\short_exam_master_file.txt debug
=cut

main(@ARGV);

=item main(@args)
    The main method of the script.

    Input: 
        @args:@mixed the command line arguments.
=cut
sub main(@args)
{
    scalar(@args) >= 1 or die "You need to provide 1 argument the masterfile\n";

    my $masterFile = $args[0];
    my $mode = $args[1];
    -e $masterFile or die "File $masterFile not found\n";
    
    my $outputFile = getOutputFileName($masterFile);

    if(defined $mode && lc($mode) == "debug")
    {
        Writer::debugSaveRandomFilled($outputFile, Parser::parse($masterFile));
    }
    else
    {
        Writer::saveToFile($outputFile, Parser::parse($masterFile)); 
    }
}

=item getOutputFileName($masterFile)
    Returns a string for the output filename. It will add a timestamp as an prefix.

    Input: 
        $masterfile:string the master file.
    
    Output:
        returns a string.
=cut
sub getOutputFileName($masterFile)
{
    my $tm = Time::Moment->now;
    return $tm->strftime('%Y%m%d-%H%M%S') . '-' . basename($masterFile);
}