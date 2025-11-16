-- ==============================================================================
-- 1. UTILITY: DATABASE AND SCHEMA SETUP
-- ==============================================================================
-- Creates the database if it does not exist
CREATE DATABASE CinemaCatalog_DB;

USE CinemaCatalog_DB;


--------------------------------------------------------------------------------
-- 2. NEW ENTITY: CrewRole (For Normalization & Efficient Filtering)
--------------------------------------------------------------------------------
CREATE TABLE CrewRole (
    -- PK: Unique ID for each role type (e.g., 1 for 'Director', 2 for 'Writer')
    role_id INT PRIMARY KEY IDENTITY(1,1),
    -- The standardized name of the role
    role_name NVARCHAR(50) NOT NULL UNIQUE,
    -- Category for easier filtering (e.g., 'Direction', 'Writing', 'Actor', 'Below-the-Line')
    category NVARCHAR(20) NOT NULL
);
GO

--------------------------------------------------------------------------------
-- 3. CORE ENTITY: Viewer (The Profiling Subject)
--------------------------------------------------------------------------------
CREATE TABLE Viewer (
    -- PK: Unique identifier for the viewer account
    viewer_id INT PRIMARY KEY IDENTITY(1,1),
    -- User's chosen unique name
    username NVARCHAR(50) NOT NULL UNIQUE,
    -- User's email address (optional unique constraint added for realism)
    email NVARCHAR(255) UNIQUE,
    -- Date the user joined (Used DATETIME2 for precision)
    joined_date DATETIME2 NOT NULL,
    -- Status flag for account activity (was 'is_available')
    is_active BIT NOT NULL DEFAULT 1,
    -- CALCULATED METRIC: The viewer's affinity for niche, low-popularity media.
    -- Updated by a stored procedure/trigger.
    niche_affinity_score DECIMAL(4, 2) NOT NULL DEFAULT 0.00
);
GO

--------------------------------------------------------------------------------
-- 4. CORE ENTITY: MediaAsset (The Inventory - Films Only)
--------------------------------------------------------------------------------
CREATE TABLE MediaAsset (
    -- PK: Unique identifier for the film/asset
    asset_id INT PRIMARY KEY IDENTITY(1,1),
    -- Official title of the film
    title NVARCHAR(255) NOT NULL,
    -- Year the film was released
    release_year INT NOT NULL,
    -- Media Type (Constrained to 'Movie' for current scope, but retained for future-proofing)
    media_type NVARCHAR(10) NOT NULL CHECK (media_type IN ('Movie', 'Series')),
    -- Total running time in minutes
    runtime_minutes INT,
    -- Funding categorization
    budget_level NVARCHAR(20) NOT NULL CHECK (budget_level IN ('Indie', 'Blockbuster', 'Mid-Budget')),
    -- CRITICAL NICHE METRIC: Lower index means more niche/less popular. 
    -- Used for score weighting.
    popularity_rank_index INT NOT NULL 
);
GO

--------------------------------------------------------------------------------
-- 5. CORE ENTITY: CrewMember (The Talent)
--------------------------------------------------------------------------------
CREATE TABLE CrewMember (
    -- PK: Unique identifier for the person (talent)
    crew_id INT PRIMARY KEY IDENTITY(1,1),
    -- Full Name is simpler for this system than separate First/Last Name
    full_name NVARCHAR(100) NOT NULL,
    -- The crew member's most common job title
    primary_role NVARCHAR(50)
    -- Birth Year is not strictly necessary for analysis, so it is omitted for simplicity
);
GO

--------------------------------------------------------------------------------
-- 6. CORE ENTITY: ExpertTag (The Objective Structural Feature)
--------------------------------------------------------------------------------
CREATE TABLE ExpertTag (
    -- PK: Unique ID for the structural tag
    tag_id INT PRIMARY KEY IDENTITY(1,1),
    -- The name of the tag (e.g., 'Non-Linear Timeline', 'Recurring Motif')
    tag_name NVARCHAR(50) NOT NULL UNIQUE,
    -- A brief, non-subjective definition of the tag
    tag_definition NVARCHAR(MAX) 
);
GO

--------------------------------------------------------------------------------
-- 7. RELATION: CrewCredit (Links Asset to CrewMember via Role)
--------------------------------------------------------------------------------
CREATE TABLE CrewCredit (
    -- COMPOSITE PK & FK: Links to the CrewMember involved
    crew_id INT NOT NULL FOREIGN KEY REFERENCES CrewMember(crew_id),
    -- COMPOSITE PK & FK: Links to the MediaAsset worked on
    asset_id INT NOT NULL FOREIGN KEY REFERENCES MediaAsset(asset_id),
    -- FK: Links to the standardized role name (Replaced 'role_type' string)
    role_id INT NOT NULL FOREIGN KEY REFERENCES CrewRole(role_id),
    -- Flag for major credits (Director, lead Actor, primary Writer)
    is_primary_credit BIT NOT NULL DEFAULT 0,

    PRIMARY KEY(crew_id, asset_id, role_id) -- The specific role on the specific asset by the specific crew member
);
GO

--------------------------------------------------------------------------------
-- 8. RELATION: ViewingLog (The Transactional Data)
--------------------------------------------------------------------------------
CREATE TABLE ViewingLog (
    -- PK: Unique ID for the specific viewing entry
    log_id INT PRIMARY KEY IDENTITY(1,1), 
    -- FK: Which viewer created the log
    viewer_id INT NOT NULL FOREIGN KEY REFERENCES Viewer(viewer_id), 
    -- FK: Which media asset was watched
    asset_id INT NOT NULL FOREIGN KEY REFERENCES MediaAsset(asset_id), 
    -- Time stamp of when the rating was recorded (Critical for decay logic if implemented)
    rating_timestamp DATETIME2 NOT NULL, 
    -- The viewer's overall enjoyment score
    critical_rating INT NOT NULL CHECK (critical_rating BETWEEN 1 AND 10), 
    -- CRITICAL NICHE METRIC: The viewer's subjective tolerance for structural complexity (1=Simple, 5=Highly Challenging)
    complexity_score INT NOT NULL CHECK (complexity_score BETWEEN 1 AND 5),
    -- Optional text comments
    comments NVARCHAR(500), 

    -- Added constraint to prevent duplicate log entries for the same asset/viewer/day
    UNIQUE (viewer_id, asset_id, rating_timestamp) 
);
GO

--------------------------------------------------------------------------------
-- 9. RELATION: ViewerTagValidation (The Subjective Niche Profiling)
--------------------------------------------------------------------------------
CREATE TABLE ViewerTagValidation (
    -- COMPOSITE PK & FK: The viewer who validated the tag
    viewer_id INT NOT NULL FOREIGN KEY REFERENCES Viewer(viewer_id),
    -- COMPOSITE PK & FK: The media asset the tag applies to
    asset_id INT NOT NULL FOREIGN KEY REFERENCES MediaAsset(asset_id), 
    -- COMPOSITE PK & FK: The specific tag being validated
    tag_id INT NOT NULL FOREIGN KEY REFERENCES ExpertTag(tag_id), 
    -- CRITICAL NICHE METRIC: The strength of the viewer's agreement with the tag (1=Weak, 5=Strong)
    agreement_intensity INT NOT NULL CHECK (agreement_intensity BETWEEN 1 AND 5),
    -- Time stamp of when the validation occurred (Used for decay of validation strength)
    validation_timestamp DATETIME2 NOT NULL, 
    
    PRIMARY KEY(viewer_id, asset_id, tag_id)
);