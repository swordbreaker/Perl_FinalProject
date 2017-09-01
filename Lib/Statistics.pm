package Statistics;

use v5.26;
use strict;
use experimental 'signatures';

use Exporter 'import';
our @EXPORT  = qw(printStats);

use List::Util qw(min max sum);

use Math::Complex;

=head1 Statistics
    This module is used to calculate the statistics and print them out.
=cut

use constant PERCENTAGE_THRESHOLD => 0.5;
use constant ANSWER_GIVEN_THRESHOLD => 0.5;

=item printStats($total, @statistics)
    Prints the stats to the console.

    Input: 
        $total:int: Total questions in the master file.
        @statistics: statistics array in the format:
        (
            {score => int, answeredQuestions=> int, file => string, answerBinaryMatrix => \@int},
            ...
        )
=cut
sub printStats($total, @statistics)
{
    my @scores = map { $_->{'score'} } @statistics;
    my @answeredQuestions = map { $_->{'answeredQuestions'} } @statistics;

    my $avgAnsweredQuestions = (sum @answeredQuestions) / (scalar @answeredQuestions);
    my $avgScores = (sum @scores) / (scalar @scores);

    (my $minScore, my $minScoreCount) = getMinAndCount(@scores);
    (my $minAnswered, my $minAnsweredCount) = getMinAndCount(@answeredQuestions);
    (my $maxScore, my $maxScoreCount) = getMaxAndCount(@scores);
    (my $maxAnswered, my $maxAnsweredCount) = getMaxAndCount(@answeredQuestions);

    say "Average number of questions answered \t $avgAnsweredQuestions";
    say "\t\t\t Minimum \t $minAnswered ($minAnsweredCount students)";
    say "\t\t\t Maximum \t $maxAnswered ($maxAnsweredCount students)";

    say "Average number of correct answers \t $avgScores";
    say "\t\t\t Minimum \t $minScore ($minScoreCount students)";
    say "\t\t\t Maximum \t $maxScore ($maxScoreCount students)";
    say "";

    my $d = scalar @scores;

    return if($d <= 1);

    my $standardDeviation = calcStandardDeviation($avgScores, @scores);

    my @belowStandardDeviation = grep { $_->{'score'} < $avgScores - $standardDeviation } @statistics;
    my @belowPercentageScore = grep { $_->{'score'}/$total < PERCENTAGE_THRESHOLD} @statistics;
    my @lessAnswersGiven = grep { $_->{'answeredQuestions'}/$total < ANSWER_GIVEN_THRESHOLD} @statistics;

    say "Results below expectation:";

    for my $stat (@belowStandardDeviation)
    {
        say $stat->{'file'} . "\t" . $stat->{'score'} . " / $total (score < (mean - standard deviation))"
    }

    for my $stat (@belowPercentageScore)
    {
        say $stat->{'file'} . "\t" . $stat->{'score'} . " / $total (score < ". PERCENTAGE_THRESHOLD*100 ."% of max score)"
    }

    for my $stat (@lessAnswersGiven)
    {
        say $stat->{'file'} . "\t" . $stat->{'score'} . " / $total (less than ". ANSWER_GIVEN_THRESHOLD*100 ."% answered)"
    }
}

=item getMinAndCount(@list)
    Get the min value of an array and count how many items have this value.

    Input: 
        @list:@int
    Output: ($min:int, $count:int)
=cut
sub getMinAndCount(@list)
{
    my $min = min @list;
    my $count = count($min, @list);
    return ($min, $count);
}

=item getMaxAndCount(@list)
    Get the max value of an array and count how many items have this value.

    Input: 
        @list:@int
    Output: ($max:int, $count:int)
=cut
sub getMaxAndCount(@list)
{
    my $max = max @list;
    my $count = count($max, @list);
    return ($max, $count);
}

=item count($value, @list)
    count the amount of item in the array.

    Input: 
        $value:int
        @list:@int

    Output: returns an int of the amount.
=cut
sub count($value, @list)
{
    return scalar (grep { $_ == $value} @list);
}

=item calcStandardDeviation($avg, @values)
    calculates the standard deviation

    Input: 
        $avg:double the average of the all items in the array
        @values:@int

    Output: standard deviation as double.
=cut
sub calcStandardDeviation($avg, @values)
{
    my $d = (scalar @values);
    my $sum = sum (map { ($_ - $avg)**2 } @values);
    return sqrt($sum/($d-1));
}

1;
# end of module