#!/usr/bin/perl 

use strict;
use warnings;

use Data::Dumper qw/Dumper/;

main(@ARGV);

sub main {
    my ($total, $run, $walk) = @_;

    my $total_secs = to_seconds($total);
    my $run_secs = to_seconds($run);
    my $walk_secs = to_seconds($walk||0);

    my @runs = ();
    my @walks = ();

    while ($total_secs > 0) {
        if ($total_secs - $run_secs < 0)  {
            push @runs, $total_secs;
            $total_secs = 0;
            last;
        } else {
            $total_secs -= $run_secs;
            push @runs, $run_secs;
        }

        last unless $total_secs;
        next unless $walk_secs;
        
        if ($total_secs - $walk_secs < 0)  {
            push @walks, $total_secs;
            $total_secs = 0;
            last;
        } else {
            $total_secs -= $walk_secs;
            push @walks, $walk_secs;
        }
    }

    my $total_runs = 0;
    my $total_walks = 0;

    $total_runs += $_ foreach @runs;
    $total_walks += $_ foreach @walks;

    my $formatted_runs = format_time($total_runs);
    my $formatted_walks = format_time($total_walks);

    printf "Total time running: %s over %d intervals\n",  $formatted_runs, scalar @runs;

    if (@walks) {
        printf "Total time walking: %s over %d intervals\n",  $formatted_walks, scalar @walks;
    }

    if (@walks && @runs != @walks) {
        printf "Last run interval is %s\n", format_time($runs[-1]);
    }
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

