#!/usr/bin/perl 

use strict;
use warnings;

use Audio::File qw//;
use PerlSpeak qw//;
use Getopt::Long qw/GetOptions/;
use File::Temp qw//;
use Data::Dumper qw/Dumper/;
use File::Copy qw/copy/;
use MP3::Info qw/set_mp3tag/;

use Carp qw/cluck confess/;

use constant SPEECH_ENGINE => 'festival';
use constant DEFAULT_BITRATE => 160;
use constant DEFAULT_WARM_COOL => '5m';

use constant DEFAULT_ARTIST => 'Playlist Generator';
use constant DEFAULT_ALBUM => 'Running Tracks';

my ($warmup, $cooldown, $program, $random, $output, $bitrate, $verbose, $title, $artist, $album);


GetOptions(
    'warmup:s' => \$warmup,
    'cooldown:s' => \$cooldown,
    'program:s' => \$program,
    'random' => \$random,
    'output:s' => \$output,
    'bitrate:s' => \$bitrate,
    'verbose' => \$verbose,
    'title:s' => \$title,
    'artist:s' => \$artist,
    'album:s' => \$album,
);

main(@ARGV);

sub main {
    my (@mp3files) = @_;

    $bitrate ||= DEFAULT_BITRATE;

    die "No input files specified\n" unless @mp3files;
    die "No output file specified\n" unless $output;
    die "No title specified\n" unless $title;
    die "Output file `$output' already exists, delete or move it first\n" if -e $output;

    my $songs = get_song_list(@mp3files);
    my $song_time = 0;
    $song_time += $_->[1] for @$songs; 

    say("Total song time is: $song_time");

    $warmup ||= DEFAULT_WARM_COOL;
    $cooldown ||= DEFAULT_WARM_COOL;

    $artist ||= DEFAULT_ARTIST;
    $album ||= DEFAULT_ALBUM;

    die "No program specified\n" unless $program;

    my $intervals = parse_program($program);

    my @routine = (
        {type => 'warmup', time => to_seconds($warmup)}, 
        @$intervals, 
        {type => 'cooldown', time => to_seconds($cooldown)}, 
    );

    my $total_time = 0;
    $total_time += $_->{time} for @routine; 

    say("Total routine time is: $total_time");

    die "Song time is less than program time: $song_time vs $total_time\n" if $song_time < $total_time;

    push @routine, {type => 'Workout complete. Total time ' . seconds_to_speech($total_time), time => 0};

    my @files = ();
    my $play_time = 0;
    for my $song (@$songs) {
        last if $play_time >= $total_time;

        say("Enqueuing $song->[0]");

        my $wav = mp3_to_wav($song->[0]);
	my $mp3 = encode_mp3_bitrate($wav, $bitrate); 

        push @files, $mp3;
	$play_time += $song->[1];
    }
    
    my $tracklist = generate_final_tracklist(\@routine, join_audio(@files));

    my $final = encode_mp3_bitrate(mp3_to_wav(join_audio(@$tracklist)), $bitrate);
    copy $final->filename(), $output;

    set_mp3tag(
        $output,
        {
            TITLE => $title, 
            ARTIST => $artist, 
            ALBUM => $album,
        }
    );
}

sub generate_final_tracklist {
    my ($routine, $music) = @_;

    my $voice_files = generate_speech(@$routine);

    my @tracklist = ();

    my $offset = 0;
    for my $set (@$routine) {
        my $voice = $voice_files->{get_set_name($set)};

        my $music = get_music_splice($music, $offset, $set->{time});

        $offset += $set->{time};

        push @tracklist, ($voice, $music);
    }

    return \@tracklist;
}

sub get_music_splice {
    my ($music, $offset, $length) = @_;

    my $until = $length ? $offset + $length : '';

    $offset = format_time_fragment($offset);
    $until = format_time_fragment($until);

    my $fh = File::Temp->new(); 

    system qw/mpgsplit -N -f -o/, $fh->filename(), $music->filename(), "[$offset-$until]" and die;

    my $wav = mp3_to_wav($fh);
    my $mp3 = encode_mp3_bitrate($wav, $bitrate); 

    return $mp3;
}

sub join_audio {
    my (@tracks) = @_;

    @tracks = map {ref $_ ? $_->filename() : $_} @tracks;

    my $fh = File::Temp->new(); 

    system qw/mpgjoin -N -f -o/, $fh->filename(), @tracks and die "Error joining files";

    return $fh;
}

sub generate_speech {
    my (@routine) = @_;

    my $ps = PerlSpeak->new();
    $ps->{tts_engine} = SPEECH_ENGINE;

    my %speech = ();
    for my $set (@routine) {
        if (not $speech{get_set_name($set)}) {
            $speech{get_set_name($set)} = generate_voice_file($ps, "$set->{type} " . seconds_to_speech($set->{time}));
        }
    }

    return \%speech;
}

sub generate_voice_file {
    my ($ps, $text) = @_;

    my $tmp = File::Temp->new();
    print $tmp "$text\n";
    close $tmp;

    my $wav = File::Temp->new();
    $ps->file2wave($tmp->filename(), $wav->filename());

    my $mp3 = encode_mp3_bitrate($wav->filename(), $bitrate);

    return $mp3;
}

sub get_song_list {
    my (@mp3files) = @_;

    my @playlist = ();

    if ($random) {
        while (@mp3files) {
            push @playlist, splice(@mp3files, rand(@mp3files), 1);
        }
    } else {
        @playlist = @mp3files;
    }

    my @songs = ();
    for my $mp3 (@playlist) {
        push @songs, [$mp3, int Audio::File->new($mp3)->audio_properties()->length()];
    }

    return \@songs;
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
        die "Unknown time string `$time'\n";
    }

    return ($hours * 3600) + ($minutes * 60) + $seconds;
}

sub seconds_to_speech {
    my ($seconds) = @_;

    my $orig = $seconds;

    my %time = ();

    $time{hour} = int($seconds / 3600);
    $seconds = $seconds % 3600;

    $time{minute} = int($seconds / 60);
    $seconds = $seconds % 60;

    $time{second} = $seconds;

    my $str = '';
    if ($seconds and $orig < 120) {
        %time = (second => $orig);
    }

    my @fragments = ();

    for (qw/hour minute second/) {
        if (my $data = $time{$_}) {
    	    my $units = $data > 1 ? "${_}s" : $_;

	    push @fragments, "$data $units"; 
	}
    }

    $str = join ' ', @fragments;

    return $str;
}

sub parse_program {
    my ($program) = @_;

    my @fragments = split ',', $program;

    my @routine = ();
    my @repeat = ();

    my $type = 0;

    for my $fragment (@fragments) {
        if ($fragment =~ /^x(\d+)$/) {
            my $repeats = $1;

            push @routine, @repeat for (1 .. $repeats);

            @repeat = (); 
        } elsif ($fragment =~ /^w(\d+)$/) {
            push @repeat, {type => 'walk', time => to_seconds($1)};
            $type = 0; 
        } elsif ($fragment =~ /^f(\d+)$/) {
            push @repeat, {type => 'fast run', time => to_seconds($1)};
            $type = 1;
        } elsif ($fragment =~ /^s(\d+)$/) {
            push @repeat, {type => 'slow run', time => to_seconds($1)};
            $type = 1;
        } else {
            push @repeat, {type => $type ? 'walk' : 'run', time => to_seconds($fragment)};
            $type = !$type;
        }
    }

    push @routine, @repeat; 

    return \@routine;
}

sub get_set_name {
    my ($set) = @_;

    return "$set->{type} $set->{time}";
}

sub format_time_fragment {
    my ($seconds) = @_;

    return '' unless $seconds;

    my $hours = int($seconds / 3600);
    $seconds = $seconds % 3600;

    my $minutes = int($seconds / 60);

    $seconds = $seconds % 60;

    return sprintf '%02d:%02d:%02d', $hours, $minutes, $seconds;
}

sub mp3_to_wav {
    my ($mp3) = @_;

    my $filename = ref $mp3 ? $mp3->filename() : $mp3;

    my $tmp = File::Temp->new();
    system qw/mpg321 --quiet --stereo -w/, $tmp->filename(), $filename; 

    return $tmp;
}

sub encode_mp3_bitrate {
    my ($wav, $bitrate) = @_;

    my $filename = ref $wav ? $wav->filename() : $wav;

    my $tmp = File::Temp->new();
    system qw/lame --cbr --quiet --resample 44100 -b/, $bitrate, $filename, $tmp->filename();

    return $tmp;
}

sub say {
    my ($msg) = @_;

    if ($verbose) {
        chomp $msg;

        print $msg, "\n";
    }
}
