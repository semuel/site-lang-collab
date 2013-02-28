package WWW::Github::Files;
use strict;
use warnings;
use LWP::UserAgent;
use JSON qw{decode_json};
use Carp;

sub new {
    my ($class, %options) = @_;

    die "Please pass a author name"
        unless exists $options{author};
    die "Please pass a resp name"
        unless exists $options{resp};
    die "Please pass either a branch name or a commit"
        unless exists $options{branch} or exists $options{commit};

    my $self = {};
    foreach my $key (qw( author resp token branch commit )) {
        next unless exists $options{$key};
        $self->{$key} = $options{$key};
    }
    if (not exists $self->{token}) {
        $self->{ua} = LWP::UserAgent->new();
    }
    $self->{apiurl} = 'https://api.github.com/repos/'.$options{author}.'/'.$options{resp};
    bless $self, $class;
}

sub open {
    my ($self, $path) = @_;
    croak("Path should start with '/'! |$path|")
        unless $path =~ m!^/!;
    my $commit = $self->__fetch_root();
    my $f_data = $self->geturl("/contents$path?ref=$commit");
    if (ref($f_data) eq 'ARRAY') {
        # a directory
        return bless { FS => $self, content => $f_data }, 'WWW::Github::Files::Dir';
    }
    elsif ($f_data->{type} eq 'file') {
        return bless $f_data, 'WWW::Github::Files::File';
    }
    else {
        croak('unrecognised file type for $path');
    }
}

sub get_file {
    my ($self, $path) = @_;
    return $self->open($path)->read();
}

sub get_dir {
    my ($self, $path) = @_;
    return $self->open($path)->readdir();
}

sub __fetch_root {
    my $self = shift;
    my $root = $self->{root_commit};
    return $root if $root;

    if ($self->{branch}) {
        my $b_data = $self->geturl('/branches/'.$self->{branch});
        $root = $b_data->{commit}->{sha};
    }
    else {
        my $c_data = $self->geturl('/git/commits/'.$self->{commit});
        $root = $self->{commit};
    }
    $self->{root_commit} = $root;
    return $root;
}

sub geturl {
    my ($self, $url, $method) = @_;
    my $token = $self->{token} || $self->{ua};
    $method ||= 'get';
    my $res = $token->$method($self->{apiurl} . $url);
    if (!$res->is_success()) {
        die "Failed to read $self->{apiurl}$url from github: ".$res->message();
    }
    my $content = $res->content;
    return decode_json($content);
}

package WWW::Github::Files::File;
use MIME::Base64 qw{decode_base64};

sub is_file { 1 }
sub is_dir { 0 }

sub read {
    my $self = shift;
    if (not $self->{content}) {
        # this is a file object created from directory listing. 
        # need to fetch the content
        my $f_data = $self->{FS}->open('/'.$self->{path});
        $self->{$_} = $f_data->{$_} for (qw{ encoding content });
    }
    if ($self->{encoding} eq 'base64') {
        return decode_base64($self->{content});
    }
    else {
        die "can not handle encoding " . $self->{encoding} . " for file ". $self->{path};
    }
}

package WWW::Github::Files::Dir;

sub is_file { 0 }
sub is_dir { 1 }

sub readdir {
    my $self = shift;
    if (not $self->{content}) {
        # this is a file object created from directory listing. 
        # need to fetch the content
        my $f_data = $self->{FS}->open('/'.$self->{path});
        $self->{content} = $f_data;
    }
    my @files;
    foreach my $rec (@{ $self->{content} }) {
        $rec->{FS} = $self->{FS};
        if ($rec->{type} eq 'file') {
            push @files, bless($rec, 'WWW::Github::Files::File');
        }
        elsif ($rec->{type} eq 'dir') {
            push @files, bless($rec, 'WWW::Github::Files::Dir');
        }
        else {
            croak('unrecognised file type: '.$rec->{type});
        }
    }
    return @files;
}

1;
