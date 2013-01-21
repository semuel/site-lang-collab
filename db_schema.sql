perl -MDBIx::Class::Schema::Loader=make_schema_at,dump_to_dir:./lib -e 'make_schema_at("LangCollab::Schema", { debug => 1 }, [ "dbi:mysql:dbname=lang_collab","root", "" ])'

CREATE TABLE user (
    id int not null primary key,
    token char(20) not null,
    data BLOB not null,
    oauth BLOB not null
);

