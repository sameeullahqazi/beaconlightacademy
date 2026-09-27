-- Diaries table
DROP TABLE IF EXISTS diaries;

CREATE TABLE diaries (
    id            INT ,
    diaryId       INT ,
    studentId     INT ,
    classId       INT ,
    title         TEXT,
    subject       TEXT,
    diaryType     TEXT,
    details       TEXT,
    className     TEXT,
    dateDue       TEXT,
    attachment    TEXT,
    attachment2   TEXT,
    bRead         INT ,
    createdDate   TEXT,
    modifiedDate  TEXT,
    dateSubmitted TEXT,
    is_deleted    INT  DEFAULT 0,
    bLocal        INT 
);

-- Diaries Comments table
DROP TABLE IF EXISTS diaries_comments;

CREATE TABLE diaries_comments (
    id           INT  PRIMARY KEY,
    diaryId      INT ,
    senderId     INT ,
    senderName   TEXT,
    message      TEXT,
    createdDate  TEXT,
    modifiedDate TEXT,
    is_deleted   INT  DEFAULT 0,
    bLocal       INT 
);

-- Correspondences table
DROP TABLE IF EXISTS correspondences;

CREATE TABLE correspondences (
    id                INT  PRIMARY KEY,
    studentId         INT ,
    subject           TEXT,
    message           TEXT,
    date              TEXT,
    dateEnded         TEXT,
    senderName        TEXT,
    contactName       TEXT,
    numUnreadMessages INT ,
    studentName       TEXT,
    bRead             INT ,
    modifiedDate      TEXT,
    is_deleted        INT  DEFAULT 0,
    bLocal            INT 
);

-- correspondences_messages table
DROP TABLE IF EXISTS correspondences_messages;

CREATE TABLE correspondences_messages (
    id               INT  PRIMARY KEY,
    correspondenceId INT ,
    senderId         INT ,
    senderName       TEXT,
    message          TEXT,
    date             TEXT,
    createdDate      TEXT,
    modifiedDate     TEXT,
    is_deleted       INT  DEFAULT 0,
    bLocal           INT 
);

-- Diaries table
DROP TABLE IF EXISTS users;

CREATE TABLE users (
    id               INT    PRIMARY KEY,
    role             TEXT  ,
    username         TEXT  ,
    prefix           TEXT  ,
    firstname        TEXT  ,
    lastname         TEXT  ,
    email            TEXT  ,
    phone            TEXT  ,
    profession       TEXT  ,
    address          TEXT  ,
    class_teacher_of INT   ,
    campus_head_of   INT   ,
    nic              TEXT  ,
    employee_id      INT   ,
    status           TEXT  ,
    date_employed    TEXT  ,
    date_quit        TEXT  ,
    basic_salary     NUMBER,
    gross_salary     NUMBER,
    campus_id        INT   ,
    account_number   TEXT  ,
    account_title    TEXT  ,
    accessToken      TEXT  ,
    students         TEXT  ,
    createdDate      TEXT  ,
    modifiedDate     TEXT  ,
    isFeeDefaulter   INT    DEFAULT 0,
    is_deleted       INT    DEFAULT 0,
    bLocal           INT   
);

-- user_data_fetches table
DROP TABLE IF EXISTS user_data_fetches;

CREATE TABLE user_data_fetches (
    username        TEXT,
    action          TEXT PRIMARY KEY CHECK (action IN ('login', 'diaries', 'diariesComments', 'correspondences', 'correspondencesMessages', 'users', 'contacts', 'classes')),
    serverTimestamp TEXT,
    numRowsFetched  INT ,
    lastID          TEXT
);

-- user_data_fetches table
DROP TABLE IF EXISTS user_data_fetch_downloads;

CREATE TABLE user_data_fetch_downloads (
    userDataFetchDownloadId INT  PRIMARY KEY,
    userId                  INT ,
    action                  TEXT,
    serverTimestamp         TEXT,
    status                  INT 
);

-- post_api_queue table
DROP TABLE IF EXISTS post_api_queue;

CREATE TABLE post_api_queue (
    id             INT  PRIMARY KEY,
    entity         TEXT,
    action         TEXT,
    url            TEXT,
    request        TEXT,
    localEntityId  INT ,
    serverEntityId INT ,
    bCompleted     INT ,
    uploadFilename TEXT,
    method         TEXT
);

-- contacts table
DROP TABLE IF EXISTS contacts;

CREATE TABLE contacts (
    id         INT ,
    username   TEXT,
    fullName   TEXT,
    role       TEXT,
    classId    TEXT,
    studentId  TEXT,
    is_deleted INT  DEFAULT 0,
    UNIQUE (id, classId, studentId) -- ✅ Added this so upserts work properly
);

-- classes table
DROP TABLE IF EXISTS classes;

CREATE TABLE classes (
    id         INT  PRIMARY KEY,
    className  TEXT,
    year       INT ,
    is_deleted INT  DEFAULT 0,
    bLocal     INT  DEFAULT 0
);

-- 1. Master Index for Diary Counts & Lists (Covers filtering AND sorting)
CREATE INDEX idx_diaries_optimized
    ON diaries(is_deleted, bRead, studentId, classId, diaryType, diaryId DESC);

-- 2. Master Index for Correspondences
CREATE INDEX idx_corr_optimized
    ON correspondences(is_deleted, studentId, bRead, modifiedDate DESC);

-- 3. Master Index for Diary Comments
CREATE INDEX idx_comments_optimized
    ON diaries_comments(diaryId, is_deleted, id ASC);