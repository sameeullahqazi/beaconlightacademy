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
    action          TEXT PRIMARY KEY CHECK (action IN ('login', 'diaries', 'diariesComments', 'correspondences', 'correspondencesMessages', 'users', 'contacts', 'classes', 'reportCardsList', 'reportCard6Plus', 'reportCardNur5')),
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

-- Report Cards: list (one row per child). classNumber only - className is
-- resolved client-side via the already-synced classes table (classId join),
-- and there's no term-label field in getAPIReportCardList()'s real response.
DROP TABLE IF EXISTS report_cards_list;

CREATE TABLE report_cards_list (
    studentId     INT  PRIMARY KEY,
    studentName   TEXT,
    classId       INT ,
    classNumber   INT ,
    classBand     TEXT, -- '6plus' or 'nur5'
    reportCardId  INT , -- NULL = not created
    modifiedDate  TEXT,
    state         TEXT, -- available / not_created / class_hidden / student_hidden / fee_defaulter
    stateMessage  TEXT, -- verbatim hidden-reason or dues text, NULL for 'available'
    bRead         INT  DEFAULT 0, -- server-authoritative, sourced from
                                   -- report_cards.bRead (not an
                                   -- app_notifications row like diary/
                                   -- correspondence - see markReportCardRead()
                                   -- backend-side), so a plain REPLACE-based
                                   -- sync is safe, same as diary/correspondence
    is_deleted    INT  DEFAULT 0
);

-- Report Cards: class 6+ print-header info (Name, Father's Name, GR#, Roll#,
-- Branch, Class, Section, Class Teacher) - matches the web print preview's
-- own header exactly (views/report-card-preview.view.php). One row per
-- report card, not per exam type, so it's its own small table rather than
-- duplicated across every report_card_summary_6plus row.
DROP TABLE IF EXISTS report_card_header_6plus;

CREATE TABLE report_card_header_6plus (
    reportCardId  INT  PRIMARY KEY,
    studentName   TEXT,
    fathersName   TEXT,
    grNo          TEXT,
    rollNo        TEXT,
    branch        TEXT,
    classNumber   INT ,
    section       TEXT,
    classTeacher  TEXT
);

-- Report Cards: class 6+ subject x examtype marks grid. Matches
-- getAPIReportCard6Plus()'s real marks[] shape exactly (verified live,
-- 2026-10-20) - highestMarks/highestInClass/totalStudents were added to
-- the backend this same session, reusing ReportCard::getHighestSubject
-- PercentageInClass()/getHighestPercentageInClass()/getOverallHighest
-- PercentageInClass(), the same functions the web preview already uses.
DROP TABLE IF EXISTS report_card_marks_6plus;

CREATE TABLE report_card_marks_6plus (
    reportCardId    INT ,
    examTypeId      INT ,
    examTypeLabel   TEXT,
    subjectId       INT ,
    subjectName     TEXT,
    maxMarks        INT ,
    obtainedMarks   INT ,
    passingMarks    INT ,
    highestMarks    INT , -- NULL if nothing entered yet for this subject/examtype across the class
    PRIMARY KEY (reportCardId, examTypeId, subjectId)
);

-- Report Cards: class 6+ per-examtype Summary tab stats + Remarks text.
-- One row per exam type, plus one isAnnual=1 row (examTypeId NULL) per
-- report card - matches the real summary[] array exactly.
DROP TABLE IF EXISTS report_card_summary_6plus;

CREATE TABLE report_card_summary_6plus (
    reportCardId      INT ,
    examTypeId        INT , -- NULL for the isAnnual row
    isAnnual          INT  DEFAULT 0,
    attendanceVal     INT ,
    attendanceTotal   INT ,
    highestInClass    INT , -- NULL if nothing entered yet
    totalStudents     INT ,
    behavior          TEXT,
    punctuality       TEXT,
    academicPotential TEXT,
    participation     TEXT,
    creativity        TEXT,
    examDate          TEXT,
    remarks           TEXT,
    PRIMARY KEY (reportCardId, isAnnual, examTypeId)
);

-- Report Cards: NUR-5 (NUR/KG/1-4) field tree, flattened and pre-joined to
-- match exactly what getAPIReportCardNur5() already returns server-side -
-- no separate local template-definition table, since the API does that
-- join once, server-side, rather than making every client re-derive it.
-- Category/sub-category are NOT columns here - they're rows in this same
-- list (fieldType='category'/'sub_category', the section name is that
-- row's own fieldLabel); grouping is a client-side rendering concern,
-- derived by scanning sortIndex order, same as the live web renderer does
-- (ReportCard::checkAndCreateNewReportCardData()). isRtl is also resolved
-- client-side (Arabic-script Unicode range check on fieldLabel/value),
-- not returned by the API - this is presentation, not business logic.
DROP TABLE IF EXISTS report_card_nur5_data;

CREATE TABLE report_card_nur5_data (
    reportCardId   INT ,
    examTypeId     INT ,
    examTypeLabel  TEXT,
    fieldId        INT ,
    fieldLabel     TEXT,
    fieldType      TEXT, -- category / sub_category / grade / attendance / remarks / conclusion
    fieldIndex     TEXT, -- display-only lettering (a/b/c/i/ii) - confirmed unreliable as a key, label use only
    value          TEXT,
    isRtl          INT  DEFAULT 0,
    sortIndex      INT ,
    PRIMARY KEY (reportCardId, examTypeId, fieldId)
);

-- 1. Master Index for Diary Counts & Lists (Covers filtering AND sorting)
CREATE INDEX idx_diaries_optimized
    ON diaries(is_deleted, bRead, studentId, classId, diaryType, diaryId DESC);

-- 1b. getDiaries()'s academic-year cutoff filter (is_deleted = 0 AND
-- createdDate >= ?) isn't covered by idx_diaries_optimized above (no
-- createdDate column in it), so it fell back to a near-full-table-scan
-- once an account's local diaries table grew large.
CREATE INDEX idx_diaries_date
    ON diaries(is_deleted, createdDate, diaryId DESC);

-- 1c. diaries has no primary key, so insertOrUpdate()'s ConflictAlgorithm
-- .replace never actually triggered a replace - every sync/push just kept
-- adding new rows for the same diary forever. Both the bulk sync path and
-- the push-insert path (_saveDiaryLocally()) now construct a matching id
-- ("{diaryId}-{classId}" for staff rows, mirroring the backend's own
-- "Unique ID trick" in getAPIDiaryList()), so this lets REPLACE correctly
-- dedupe going forward.
CREATE UNIQUE INDEX idx_diaries_unique_id
    ON diaries(id);

-- 2. Master Index for Correspondences
CREATE INDEX idx_corr_optimized
    ON correspondences(is_deleted, studentId, bRead, modifiedDate DESC);

-- 3. Master Index for Diary Comments
CREATE INDEX idx_comments_optimized
    ON diaries_comments(diaryId, is_deleted, id ASC);