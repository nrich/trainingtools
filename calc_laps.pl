#!/usr/bin/perl 

use strict;
use warnings;

use constant MILES_CONVERSION => 1.609344;

main(@ARGV);

sub main {
    my ($distance, $time, $lap_distance) = @_;

    my $seconds = to_seconds($time||0);
    my $cm = to_centimetres($distance||0);
    my $lap_cm = to_centimetres($lap_distance||'50m');

    my $laps = $cm / $lap_cm;

    my $time_per_lap = int($seconds/$laps);

    print "$laps laps\n";
    print "$time_per_lap seconds per lap\n";
}

sub format_time_output {
    my ($minutes) = @_;

    my ($min,  $sec) = split '\.', "$minutes";
    $sec = int($sec * 0.6);
    $sec = sprintf('%02d', $sec);

    return "$min:$sec";
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

sub to_centimetres {
    my ($distance) = @_;

    my ($km, $m, $cm) = (0, 0, 0);

    if ($distance =~ /^(?:(\d+(\.\d+)?)km)?(?:(\d+(\.\d+)?)m)?(?:(\d+)cm)?$/) {
        $km = $1||0;
        $m = $2||0;
        $cm = $3||0;
    } elsif ($distance =~ /^(\d+(\.\d+)?)miles?$/) {
        $km = $1 * MILES_CONVERSION;
    } else {
        $km = $distance;
    }

    return (100_000 * $km) + ($m * 100) + $cm;
}
