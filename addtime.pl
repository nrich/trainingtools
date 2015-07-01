#!/usr/bin/perl 

use strict;
use warnings;

main(@ARGV);

sub main {
    my @list = @_;
    
    my $result = to_seconds(shift @list);

    while (@list) {
        $result = calc($result, shift @list, to_seconds(shift @list));
    }

    print format_time($result), "\n";
}

sub calc {
    my ($left, $operand, $right) = @_;

    $operand ||= '+';
    my $left_seconds = to_seconds($left||0);
    my $right_seconds = to_seconds($right||0);

    my $result = 0;
    if ($operand eq '+') {
        $result = $left_seconds + $right_seconds;
    } elsif ($operand eq '-') {
        $result = abs($left_seconds - $right_seconds);
    }

    return $result;
}

sub to_seconds {
    my ($time) = @_;

    my ($hours, $minutes, $seconds) = (0, 0, 0);

    if ($time =~ /^(?:(\d+)h)?(?:(\d+)m)?(?:(\d+)s)?$/) {
        $hours = $1||0;
        $minutes = $2||0;
        $seconds = $3||0;
    } elsif ($time =~ /^(?:(\d+):)?(?:(\d\d):)?(?:(\d\d))?$/) {
        $hours = $1||0;
        $minutes = $2||0;
        $seconds = $3||0;
    } elsif ($time =~ /^(\d+)$/) {
        $seconds = $1;
    } else {
        $seconds = 0;
    }

    return ($hours * 3600) + ($minutes * 60) + $seconds;
}

sub format_time {
    my ($seconds) = @_;

    my $hours = int($seconds / 3600);
    $seconds = $seconds % 3600;

    my $minutes = int($seconds / 60);

    $seconds = $seconds % 60;

    my $ftm_str = '';
    my @args = ();

    if ($hours) {
        $ftm_str .= '%dh';
        push @args, $hours;
    }

    if ($minutes) {
        $ftm_str .= '%dm';
        push @args, $minutes;
    }

    if ($seconds) {
        $ftm_str .= '%ds';
        push @args, $seconds;
    }

    unless (@args) {
        $ftm_str = '%ds';
        push @args, 0;
    }

    return sprintf $ftm_str, @args;
}
