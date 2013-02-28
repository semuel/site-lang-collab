package WWW::Github::Files;
use strict;
use warnings;
use LWP::UserAgent;
use JSON qw{decode_json};
use MIME::Base64 qw{decode_base64};
use Data::Dumper;
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

sub get_file {
    my ($self, $path) = @_;
    my $f_data = $self->get_file_meta($path);
    croak("requested file is not a file! |$path|")
        unless $f_data->{type} eq 'file';
    if ($f_data->{encoding} eq 'base64') {
        return decode_base64($f_data->{content});
    }
    else {
        die "can not handle encoding " . $f_data->{encoding} . " for file $path";
    }
}

sub get_dir {
    my ($self, $path) = @_;
    my $f_data = $self->get_file_meta($path);
    croak('Are you sure $path is a directory?')
        unless ref($f_data) eq 'ARRAY';
    my @dirs = grep { 'dir' eq $_->{type} } @$f_data;
    my @files = grep { 'file' eq $_->{type} } @$f_data;
    return (\@dirs, \@files);
}

sub get_file_meta {
    my ($self, $path) = @_;
    croak("Path should start with '/'! |$path|")
        unless $path =~ m!^/!;
    my $commit = $self->__fetch_root();
    my $f_data = $self->geturl("/contents$path?ref=$commit");
    return $f_data;
}

sub refresh {
    my ($self) = @_;
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

sub is_file { 1 }
sub is_dir { 0 }

sub content {
    my $self = shift;
    if ($self->{encoding} eq 'base64') {
        return decode_base64($self->{content});
    }
    else {
        die "can not handle encoding " . $self->{encoding} . " for file $path";
    }
}

package WWW::Github::Files::Dir;

sub is_file { 0 }
sub is_dir { 1 }


1;
