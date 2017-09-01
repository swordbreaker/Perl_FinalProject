package ParserMover;

use v5.26;
use strict;
use experimental 'signatures';

use Exporter 'import';
our @EXPORT  = qw(init cosumeLine peekLine isEmpty length getFileLine);

=head1 ParserMover
    This module is used by the Parser it takes track of the current line.
=cut

my @lines;
my $fileLine = -1;  #we want to know the line we are after we consumed the line so we need to start by -1

=item init(@fileLines)
    init the module

    Input: 
        @fileLine:@string an array with all lines as strings of the file.
=cut
sub init(@fileLines)
{
    @lines = @fileLines;
    $fileLine = -1; #we want to know the line we are after we consumed the line so we need to start by -1
}

=item consumeLine()
    Shifts the array and return the line. Also keeps track of the fileLine.

    Output: returns a string of the consumed line.
=cut
sub consumeLine()
{
    die "lines are empty" if isEmpty();
    $fileLine++;
    return shift @lines;
}

=item peekLine()
    Returns a line without consuming it.

    Output: returns a string of the next line.
=cut
sub peekLine()
{
    die "lines are empty" if isEmpty();
    return $lines[0];
}

=item isEmpty()
    Check if there are no more lines left.

    Output: a boolean if there are no more lines.
=cut
sub isEmpty()
{
    return ParserMover::length() <= 0;
}

=item length()
    Returns the length of the remaining lines.

    Output: an int of the number of remaining lines.
=cut
sub length()
{
    return scalar(@lines);
}

=item getFileLine()
    Returns the current file line.

    Output: an int with the file line.
=cut
sub getFileLine()
{
    return $fileLine;
}

1;
# end of module