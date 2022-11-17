create extension if not exists "uuid-ossp";

create table "User"
(
    user_id                         uuid      default uuid_generate_v4() not null
        constraint user_pk
            primary key,
    email                           varchar(255)                         not null,
    password                        varchar(255),
    exercise_duration_hour          integer,
    exercise_duration_minute        integer,
    created_at                      timestamp default CURRENT_TIMESTAMP,
    updated_at                      timestamp default CURRENT_TIMESTAMP,
    email_verification_token        varchar(100),
    email_verification_token_expiry timestamp,
    email_verified                  boolean   default false,
    user_profile_image              varchar(255)
);

alter table "User"
    owner to melodistic;

create unique index user_email_verification_token_uindex
    on "User" (email_verification_token);

create table "Track"
(
    track_id        uuid      default uuid_generate_v4() not null
        constraint track_pk
            primary key,
    track_name      varchar(255),
    track_image_url varchar(255),
    track_path      varchar(255),
    muscle_group    varchar(50),
    description     varchar(255),
    duration        integer,
    is_public       boolean   default false,
    created_at      timestamp default CURRENT_TIMESTAMP,
    updated_at      timestamp default CURRENT_TIMESTAMP,
    tag             varchar(255)
);

alter table "Track"
    owner to melodistic;

create table "UserFavorite"
(
    user_favorite_id uuid      default uuid_generate_v4() not null
        constraint userfavorite_pk
            primary key,
    user_id          uuid
        constraint userfavorite_user_user_id_fk
            references "User",
    track_id         uuid
        constraint userfavorite_track_track_id_fk
            references "Track",
    created_at       timestamp default CURRENT_TIMESTAMP,
    updated_at       timestamp default CURRENT_TIMESTAMP,
    unique (user_id, track_id)
);

alter table "UserFavorite"
    owner to melodistic;

create table "GeneratedTrack"
(
    generated_track_id uuid      default uuid_generate_v4() not null
        constraint generatedtrack_pk
            primary key,
    user_id            uuid
        constraint generatedtrack_user_user_id_fk
            references "User",
    track_id           uuid
        constraint generatedtrack_track_track_id_fk
            references "Track",
    created_at         timestamp default CURRENT_TIMESTAMP,
    updated_at         timestamp default CURRENT_TIMESTAMP,
    unique (user_id, track_id)
);

alter table "GeneratedTrack"
    owner to melodistic;

create table "ProcessedMusic"
(
    process_id    uuid      default uuid_generate_v4() not null
        constraint processedmusic_pk
            primary key,
    user_id       uuid
        constraint processedmusic_user_user_id_fk
            references "User",
    music_name    varchar(255),
    duration      integer,
    mood          varchar(10),
    bpm           numeric,
    created_at    timestamp default CURRENT_TIMESTAMP,
    updated_at    timestamp default CURRENT_TIMESTAMP,
    is_processing boolean   default true
);

alter table "ProcessedMusic"
    owner to melodistic;

create table "Music"
(
    music_id           uuid      default uuid_generate_v4() not null
        constraint music_pk
            primary key,
    music_name         varchar(255),
    music_path         varchar(255),
    music_feature_path varchar(255),
    bpm                numeric,
    mood               varchar(10),
    is_system          boolean,
    created_at         timestamp default CURRENT_TIMESTAMP,
    updated_at         timestamp default CURRENT_TIMESTAMP
);

alter table "Music"
    owner to melodistic;

create table "ProcessedMusicExtract"
(
    processed_music_extract_id uuid      default uuid_generate_v4() not null
        constraint processedmusicextract_pk
            primary key,
    processed_id               uuid
        constraint processedmusicextract_processedmusic_process_id_fk
            references "ProcessedMusic",
    music_id                   uuid
        constraint processedmusicextract_music_music_id_fk
            references "Music",
    created_at                 timestamp default CURRENT_TIMESTAMP,
    updated_at                 timestamp default CURRENT_TIMESTAMP
);

alter table "ProcessedMusicExtract"
    owner to melodistic;

create function add_music_extract(_processed_id uuid, _music_name character varying, _music_path character varying, _music_feature_path character varying, _bpm numeric, _mood character varying) returns uuid
    language plpgsql
as
$$
DECLARE _music_id uuid;
BEGIN
    INSERT INTO public."Music" (music_name, music_path, music_feature_path, bpm, mood, is_system)
    VALUES (_music_name, _music_path, _music_feature_path, _bpm, _mood, false)
    RETURNING "Music".music_id into _music_id;
    INSERT INTO public."ProcessedMusicExtract" (processed_id, music_id)
    VALUES (_processed_id, _music_id);
    RETURN _music_id;
END;
$$;

alter function add_music_extract(uuid, varchar, varchar, varchar, numeric, varchar) owner to melodistic;

create function add_process_music(_user_id uuid, _music_name character varying, _duration numeric) returns uuid
    language plpgsql
as
$$
DECLARE _processed_id uuid;
BEGIN
    INSERT INTO public."ProcessedMusic" (user_id, music_name, duration, is_processing)
    VALUES (_user_id, _music_name, _duration, true)
    RETURNING "ProcessedMusic".process_id into _processed_id;
    RETURN _processed_id;
END;
$$;

alter function add_process_music(uuid, varchar, numeric) owner to melodistic;

create function create_new_track(_track_name character varying, _track_path character varying, _muscle_group character varying, _description character varying, _duration integer) returns uuid
    language plpgsql
as
$$
DECLARE _track_id uuid;
BEGIN
    INSERT INTO public."Track" (track_name, muscle_group, description, duration, is_public)
    VALUES (_track_name, _muscle_group, _description, _duration, false)
    RETURNING "Track".track_id into _track_id;
    UPDATE public."Track" SET track_path = concat(_track_path,'/',_track_id,'.wav') WHERE track_id = _track_id;
    RETURN _track_id;
END;
$$;

alter function create_new_track(varchar, varchar, varchar, varchar, integer) owner to melodistic;

create function get_library(_user_id uuid)
    returns TABLE(track_id uuid, track_name character varying, track_image_url character varying, track_path character varying, description character varying, duration integer, is_favorite boolean)
    language plpgsql
as
$$
BEGIN
    RETURN QUERY(SELECT GT.track_id, T.track_name, T.track_image_url, T.track_path, T.description, T.duration, (CASE when UF.user_favorite_id is not null then true else false end) as is_favorite FROM "GeneratedTrack" GT
    join "Track" T on T.track_id = GT.track_id
    join "User" U on U.user_id = GT.user_id
    left join "UserFavorite" UF on T.track_id = UF.track_id and U.user_id = UF.user_id
    WHERE GT.user_id = _user_id
);

END;
$$;

alter function get_library(uuid) owner to melodistic;

create function get_music_info(_process_ids uuid[])
    returns TABLE(music_id uuid, music_name character varying, music_path character varying, music_feature_path character varying)
    language plpgsql
as
$$
BEGIN
    RETURN QUERY(SELECT m.music_id, m.music_name, m.music_path, m.music_feature_path FROM "Music" m JOIN "ProcessedMusicExtract" pme ON m.music_id = pme.music_id WHERE processed_id = any(_process_ids));

END;
$$;

alter function get_music_info(uuid[]) owner to melodistic;

create function get_song_list(_mood character varying, _section_type character varying)
    returns TABLE(music_id uuid, music_name character varying, music_path character varying, music_feature_path character varying)
    language plpgsql
as
$$
BEGIN
    IF _section_type = 'WARMUP' or _section_type = 'COOLDOWN' or _section_type = 'BREAK' THEN
        RETURN QUERY(SELECT m.music_id, m.music_name, m.music_path, m.music_feature_path FROM public."Music" AS m WHERE m.mood = _mood AND bpm >= 0 AND bpm <= 120 AND is_system = true);
    ELSE
        RETURN QUERY(SELECT m.music_id, m.music_name, m.music_path, m.music_feature_path FROM public."Music" AS m WHERE m.mood = _mood AND bpm > 120 AND bpm <= 200 AND is_system = true);
    END IF;
END;
$$;

alter function get_song_list(varchar, varchar) owner to melodistic;

create function update_process_music(_process_id uuid, _mood character varying, _bpm numeric) returns uuid
    language plpgsql
as
$$
BEGIN
    UPDATE public."ProcessedMusic" SET mood = _mood, bpm = _bpm, is_processing = false, updated_at= current_timestamp WHERE process_id = _process_id;
    RETURN _process_id;
END;
$$;

alter function update_process_music(uuid, varchar, numeric) owner to melodistic;


