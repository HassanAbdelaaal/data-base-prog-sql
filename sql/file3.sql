-- ==============================================================================
-- INDEXING STRATEGY FOR CINEMA CATALOG
-- Optimizes JOINs and WHERE clauses used by the 5 analytical functions.
-- ==============================================================================
USE CinemaCatalog_DB;
GO

-- ==============================================================================
-- B+ TREE INDEXES SECTION
-- ==============================================================================

-- 1. Indexing ViewingLog for Viewer/Asset lookups
CREATE NONCLUSTERED INDEX IX_ViewingLog_ViewerID ON ViewingLog (viewer_id);
CREATE NONCLUSTERED INDEX IX_ViewingLog_AssetID ON ViewingLog (asset_id);
GO

-- 2. Indexing MediaAsset for Niche Score Calculation
-- This assists the USP when finding media by popularity rank
CREATE NONCLUSTERED INDEX IX_MediaAsset_PopularityRank ON MediaAsset (popularity_rank_index);
GO

-- 3. Indexing CrewCredit for Crew Affinity Analysis (udf_GetCrewAffinitySuggestions)
CREATE NONCLUSTERED INDEX IX_CrewCredit_CrewID ON CrewCredit (crew_id);
CREATE NONCLUSTERED INDEX IX_CrewCredit_AssetID ON CrewCredit (asset_id);
GO

-- 4. Critical Index for ViewerTagValidation (Clustering & Bias Reports)
-- This is the most crucial index for speeding up the complex JOINs in the UDFs.
CREATE NONCLUSTERED INDEX IX_VTV_TagViewer ON ViewerTagValidation (tag_id, viewer_id);
GO


-- ==============================================================================
-- VIEWS SECTION
-- Creating at least 2 Views for commonly accessed data patterns
-- ==============================================================================

--------------------------------------------------------------------------------
-- VIEW 1: vw_ViewerRatingSummary
-- Purpose: Provides a comprehensive summary of each viewer's rating behavior
-- This view is used frequently on the user profile dashboard
--------------------------------------------------------------------------------
CREATE VIEW vw_ViewerRatingSummary AS
SELECT 
    V.viewer_id,
    V.username,
    V.email,
    V.niche_affinity_score,
    V.joined_date,
    V.is_active,
    COUNT(DISTINCT VL.asset_id) AS TotalMoviesWatched,
    AVG(CAST(VL.critical_rating AS DECIMAL(4, 2))) AS AverageRating,
    MAX(VL.critical_rating) AS HighestRating,
    MIN(VL.critical_rating) AS LowestRating,
    AVG(CAST(VL.complexity_score AS DECIMAL(4, 2))) AS AverageComplexityPreference,
    MAX(VL.rating_timestamp) AS LastViewingDate,
    COUNT(DISTINCT VTV.tag_id) AS TotalTagsValidated,
    -- Calculate how many days since they joined
    DATEDIFF(DAY, V.joined_date, GETDATE()) AS DaysSinceJoined
FROM 
    Viewer V
LEFT JOIN 
    ViewingLog VL ON V.viewer_id = VL.viewer_id
LEFT JOIN 
    ViewerTagValidation VTV ON V.viewer_id = VTV.viewer_id
GROUP BY 
    V.viewer_id, 
    V.username, 
    V.email, 
    V.niche_affinity_score, 
    V.joined_date, 
    V.is_active;
GO

--------------------------------------------------------------------------------
-- VIEW 2: vw_MovieDetailedStats
-- Purpose: Provides detailed statistics for each movie including ratings and tags
-- Used for the movie detail pages and recommendation algorithms
--------------------------------------------------------------------------------
CREATE VIEW vw_MovieDetailedStats AS
SELECT 
    MA.asset_id,
    MA.title,
    MA.release_year,
    MA.media_type,
    MA.runtime_minutes,
    MA.budget_level,
    MA.popularity_rank_index,
    -- Rating statistics
    COUNT(DISTINCT VL.viewer_id) AS TotalViewers,
    AVG(CAST(VL.critical_rating AS DECIMAL(4, 2))) AS AverageRating,
    MAX(VL.critical_rating) AS HighestRating,
    MIN(VL.critical_rating) AS LowestRating,
    AVG(CAST(VL.complexity_score AS DECIMAL(4, 2))) AS AverageComplexity,
    -- Tag statistics
    COUNT(DISTINCT VTV.tag_id) AS UniqueTags,
    COUNT(VTV.viewer_id) AS TotalTagValidations,
    AVG(CAST(VTV.agreement_intensity AS DECIMAL(4, 2))) AS AverageTagIntensity,
    -- Crew statistics
    COUNT(DISTINCT CC.crew_id) AS TotalCrewMembers,
    -- Calculate a popularity score based on number of viewers
    CASE 
        WHEN COUNT(DISTINCT VL.viewer_id) >= 5 THEN 'Popular'
        WHEN COUNT(DISTINCT VL.viewer_id) >= 2 THEN 'Moderate'
        ELSE 'Niche'
    END AS PopularityCategory
FROM 
    MediaAsset MA
LEFT JOIN 
    ViewingLog VL ON MA.asset_id = VL.asset_id
LEFT JOIN 
    ViewerTagValidation VTV ON MA.asset_id = VTV.asset_id
LEFT JOIN 
    CrewCredit CC ON MA.asset_id = CC.asset_id
GROUP BY 
    MA.asset_id, 
    MA.title, 
    MA.release_year, 
    MA.media_type, 
    MA.runtime_minutes, 
    MA.budget_level, 
    MA.popularity_rank_index;
GO

--------------------------------------------------------------------------------
-- VIEW 3: vw_CrewMemberPortfolio
-- Purpose: Shows each crew member's complete portfolio with statistics
-- Used for crew member profile pages and discovery features
--------------------------------------------------------------------------------
CREATE VIEW vw_CrewMemberPortfolio AS
SELECT 
    CM.crew_id,
    CM.full_name,
    CM.primary_role,
    COUNT(DISTINCT CC.asset_id) AS TotalProjects,
    COUNT(DISTINCT MA.budget_level) AS BudgetLevelsDiversity,
    STRING_AGG(MA.budget_level, ', ') WITHIN GROUP (ORDER BY MA.budget_level) AS BudgetLevels,
    STRING_AGG(CR.role_name, ', ') WITHIN GROUP (ORDER BY CR.role_name) AS AllRoles,
    -- Calculate average rating across all their projects
    AVG(CAST(VL.critical_rating AS DECIMAL(4, 2))) AS AvgProjectRating,
    MIN(MA.release_year) AS FirstProjectYear,
    MAX(MA.release_year) AS LatestProjectYear,
    -- Count how many of their projects are primary credits
    SUM(CASE WHEN CC.is_primary_credit = 1 THEN 1 ELSE 0 END) AS PrimaryCredits
FROM 
    CrewMember CM
LEFT JOIN 
    CrewCredit CC ON CM.crew_id = CC.crew_id
LEFT JOIN 
    MediaAsset MA ON CC.asset_id = MA.asset_id
LEFT JOIN 
    CrewRole CR ON CC.role_id = CR.role_id
LEFT JOIN 
    ViewingLog VL ON MA.asset_id = VL.asset_id
GROUP BY 
    CM.crew_id, 
    CM.full_name, 
    CM.primary_role;
GO

--------------------------------------------------------------------------------
-- VIEW 4: vw_TagPopularityAnalysis
-- Purpose: Analyzes the popularity and usage patterns of expert tags
-- Used for tag-based recommendations and trend analysis
--------------------------------------------------------------------------------
CREATE VIEW vw_TagPopularityAnalysis AS
SELECT 
    ET.tag_id,
    ET.tag_name,
    ET.category,
    ET.tag_definition,
    COUNT(DISTINCT VTV.viewer_id) AS TotalValidators,
    COUNT(DISTINCT VTV.asset_id) AS TotalMoviesTagged,
    AVG(CAST(VTV.agreement_intensity AS DECIMAL(4, 2))) AS AvgAgreementIntensity,
    -- Calculate how many strong validations (intensity >= 4)
    SUM(CASE WHEN VTV.agreement_intensity >= 4 THEN 1 ELSE 0 END) AS StrongValidations,
    -- Calculate percentage of strong validations
    CASE 
        WHEN COUNT(VTV.viewer_id) > 0 THEN 
            (CAST(SUM(CASE WHEN VTV.agreement_intensity >= 4 THEN 1 ELSE 0 END) AS DECIMAL(5,2)) / 
             COUNT(VTV.viewer_id)) * 100
        ELSE 0
    END AS StrongValidationPercentage,
    -- Most recent validation date
    MAX(VTV.validation_timestamp) AS LastValidationDate
FROM 
    ExpertTag ET
LEFT JOIN 
    ViewerTagValidation VTV ON ET.tag_id = VTV.tag_id
GROUP BY 
    ET.tag_id, 
    ET.tag_name, 
    ET.category, 
    ET.tag_definition;
GO


-- ==============================================================================
-- HASH INDEXES SECTION
-- SQL Server implements hash-like lookups through UNIQUE constraints
-- These provide O(1) average lookup time for equality searches
-- ==============================================================================

--------------------------------------------------------------------------------
-- HASH INDEX 1: Unique constraint on Viewer.username
-- Purpose: Provides fast hash-based lookup for user login authentication
-- This constraint already exists in the table definition, but we document it here
-- for clarity as part of the hash indexing strategy
--------------------------------------------------------------------------------
-- Already implemented in file1.sql as:
-- username NVARCHAR(50) NOT NULL UNIQUE
-- This UNIQUE constraint creates an implicit hash-like index for fast lookups

-- To verify or recreate if needed:
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'UQ_Viewer_Username' AND object_id = OBJECT_ID('Viewer'))
BEGIN
    ALTER TABLE Viewer
    ADD CONSTRAINT UQ_Viewer_Username UNIQUE (username);
END
GO

--------------------------------------------------------------------------------
-- HASH INDEX 2: Unique constraint on Viewer.email
-- Purpose: Provides fast hash-based lookup for email-based user searches
-- Ensures email uniqueness and enables O(1) lookups for password reset functionality
--------------------------------------------------------------------------------
-- Already implemented in file1.sql as:
-- email NVARCHAR(255) UNIQUE
-- This UNIQUE constraint creates an implicit hash-like index for fast lookups

-- To verify or recreate if needed:
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'UQ_Viewer_Email' AND object_id = OBJECT_ID('Viewer'))
BEGIN
    ALTER TABLE Viewer
    ADD CONSTRAINT UQ_Viewer_Email UNIQUE (email);
END
GO

--------------------------------------------------------------------------------
-- HASH INDEX 3: Unique constraint on ExpertTag.tag_name
-- Purpose: Provides fast hash-based lookup when searching for tags by name
-- Ensures tag name uniqueness and enables O(1) lookups for tag validation
--------------------------------------------------------------------------------
-- Already implemented in file1.sql as:
-- tag_name NVARCHAR(50) NOT NULL UNIQUE
-- This UNIQUE constraint creates an implicit hash-like index for fast lookups

-- To verify or recreate if needed:
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'UQ_ExpertTag_TagName' AND object_id = OBJECT_ID('ExpertTag'))
BEGIN
    ALTER TABLE ExpertTag
    ADD CONSTRAINT UQ_ExpertTag_TagName UNIQUE (tag_name);
END
GO

--------------------------------------------------------------------------------
-- HASH INDEX 4: Unique constraint on CrewRole.role_name
-- Purpose: Provides fast hash-based lookup when filtering by role type
-- Ensures role name uniqueness and enables O(1) lookups for crew filtering
--------------------------------------------------------------------------------
-- Already implemented in file1.sql as:
-- role_name NVARCHAR(50) NOT NULL UNIQUE
-- This UNIQUE constraint creates an implicit hash-like index for fast lookups

-- To verify or recreate if needed:
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'UQ_CrewRole_RoleName' AND object_id = OBJECT_ID('CrewRole'))
BEGIN
    ALTER TABLE CrewRole
    ADD CONSTRAINT UQ_CrewRole_RoleName UNIQUE (role_name);
END
GO


-- ==============================================================================
-- DOCUMENTATION: Hash Index Strategy in SQL Server
-- ==============================================================================
-- SQL Server does not support traditional hash indexes like MySQL or PostgreSQL.
-- Instead, we use UNIQUE constraints which provide similar O(1) lookup performance
-- for equality searches through SQL Server's internal hash-based structures.
--
-- Benefits of this approach:
-- 1. Fast equality lookups (username = 'john', email = 'test@example.com')
-- 2. Automatic uniqueness enforcement at database level
-- 3. No additional storage overhead compared to B-tree indexes
-- 4. Optimal for high-cardinality columns with unique values
--
-- Limitations:
-- 1. Only works for equality searches (=), not ranges (<, >, BETWEEN)
-- 2. Cannot be used with LIKE or other pattern matching
-- 3. Requires unique values in the column
--
-- Alternative: Memory-Optimized Tables with Hash Indexes
-- For even better performance, SQL Server supports true hash indexes on
-- memory-optimized tables, but this requires enabling In-Memory OLTP feature.
-- ==============================================================================