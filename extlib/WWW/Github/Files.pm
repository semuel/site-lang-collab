package WWW::Github::Files;
use strict;
use warnings;
use LWP::UserAgent;
use JSON qw{decode_json};
use MIME::Base64 qw{decode_base64};
use Data::Dumper;

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
    my @path_list = split '/', $path;
    die "files need to start with '/'"
        unless @path_list > 1 and $path_list[0] eq '';
    shift @path_list;
    $self->__fetch_tree(undef, @path_list);
    my $meta = $self->__get_file_meta($path);
    return unless $meta;
    return unless $meta->{type} eq 'blob';
    my $f_data = $self->geturl('/git/blobs/'.$meta->{sha});
    if ($f_data->{encoding} eq 'base64') {
        return decode_base64($f_data->{content});
    }
    else {
        die "can not handle encoding " . $f_data->{encoding} . " for file $path";
    }
}

sub get_dir {
    my ($self, $path) = @_;
}

sub get_file_meta {
    my ($self, $path) = @_;
}

sub __get_file_meta {
    my ($self, $path) = @_;
    my @path_list = split '/', $path;
    die "files need to start with '/'"
        unless @path_list > 1 and $path_list[0] eq '';
    shift @path_list;
    my $dir_obj = $self->{root_dir};
    while (my $filename = shift @path_list) {
        my ($filedata) = grep { $filename eq $_->{path} } @{ $dir_obj->{content} };
        return unless $filedata;
        return if @path_list and $filedata->{type} ne 'tree';
        $dir_obj = $filedata;
    }
    return $dir_obj;
}

sub refresh {
    my ($self) = @_;
}

sub __fetch_tree {
    my ($self, $dir_obj, @path) = @_;
    if (not $dir_obj) {
        $dir_obj = $self->{root_dir} || $self->__fetch_root();
    }
    while (@path) {
        if (not $dir_obj->{content}) {
            my $data = $self->geturl('/git/trees/'.$dir_obj->{sha});
            $dir_obj->{content} = $data->{tree};
        }
        my $filename = shift @path;
        my ($filedata) = grep { $filename eq $_->{path} } @{ $dir_obj->{content} };
        return unless $filedata;
        last unless $filedata->{type} eq 'tree';
        $dir_obj = $filedata;
    }
}

sub __fetch_root {
    my $self = shift;
    my $root;
    if ($self->{branch}) {
        my $b_data = $self->geturl('/branches/'.$self->{branch});
        $root = {
            commit => $b_data->{commit}->{sha},
            sha => $b_data->{commit}->{commit}->{tree}->{sha},
            type => 'tree',
        }
    }
    else {
        my $c_data = $self->geturl('/git/commits/'.$self->{commit});
        $root = {
            commit => $c_data->{sha},
            sha => $c_data->{tree}->{sha},
            type => 'tree',
        }
    }
    $self->{root_dir} = $root;
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

1;
