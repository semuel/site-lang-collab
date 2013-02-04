perl -MDBIx::Class::Schema::Loader=make_schema_at,dump_to_dir:./lib -e 'make_schema_at("LangCollab::Schema", { debug => 1 }, [ "dbi:mysql:dbname=lang_collab","root", "" ])'

CREATE TABLE user (
    id int not null primary key,
    token char(20) not null,
    data BLOB not null,
    oauth BLOB not null
);

CREATE TABLE project (
    id int not null primary key auto_increment,
    url varchar(255) not null,
    owner int not null,
    resp_name varchar(255) not null,
    description varchar(255) not null,
    master_branch varchar(255) not null,
    dev_branch varchar(255),
    main_lang char(2) not null
);

CREATE TABLE readmes (
    prj_id int not null,
    lang char(2) not null,
    readme text not null,
    format char(5),
    PRIMARY KEY (prj_id, lang)
);
