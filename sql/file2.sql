-- ==============================================================================
-- MS SQL SERVER BACKEND LOGIC FOR CINEMA CATALOG
-- This script contains the Stored Procedure for updating the Niche Score
-- and a Function for finding Viewer Clusters (Similar Users).
-- ==============================================================================
USE CinemaCatalog_DB;
GO

--------------------------------------------------------------------------------
-- STORED PROCEDURE: usp_CalculateNicheAffinity
-- Purpose: Calculates and updates the Niche Affinity Score for all Viewers.
-- Logic: Score is a weighted average of CriticalRating, inversely proportional
--        to the Asset's Popularity Rank. This rewards high ratings on niche media.
--------------------------------------------------------------------------------
CREATE PROCEDURE usp_CalculateNicheAffinity
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Calculate the weighted score for each viewer
    WITH ViewerScores AS (
        SELECT
            V.viewer_id,
            -- Calculate a Weighted Rating: (Critical Rating * Niche Multiplier)
            -- Niche Multiplier is based on PopularityRankIndex (e.g., 100 - Index)
            SUM(CAST(L.critical_rating AS DECIMAL(4, 2)) * (100.0 - A.popularity_rank_index) / 100.0) AS TotalWeightedScore,
            COUNT(L.log_id) AS TotalLogs
        FROM 
            Viewer V
        JOIN 
            ViewingLog L ON V.viewer_id = L.viewer_id
        JOIN 
            MediaAsset A ON L.asset_id = A.asset_id
        GROUP BY 
            V.viewer_id
    )
    -- 2. Update the Viewer table with the new calculated score
    UPDATE V
    SET V.niche_affinity_score = 
        CASE
            -- Avoid division by zero and ensure a score is calculated only if logs exist
            WHEN S.TotalLogs > 0 THEN (S.TotalWeightedScore / S.TotalLogs) * 2.0 -- Scale score up to a maximum of 20
            ELSE 0.00
        END
    FROM 
        Viewer V
    JOIN 
        ViewerScores S ON V.viewer_id = S.viewer_id;

    -- NOTE: For the 'decay' feature, a WHERE clause would be added to the JOIN 
    -- to only include logs from the last N days.
END
GO

ALTER PROCEDURE usp_CalculateNicheAffinity
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Calculate the weighted score for each viewer
    WITH ViewerScores AS (
        SELECT
            V.viewer_id,
            -- FIX: Force intermediate calculation to DECIMAL(10, 4) to preserve precision 
            -- during aggregation (SUM) and division (AVG).
            SUM(
                -- Critical Rating (1-10)
                CAST(L.critical_rating AS DECIMAL(10, 4)) 
                * -- Niche Multiplier (Index/100, e.g., 95/100 = 0.95)
                (CAST(A.popularity_rank_index AS DECIMAL(10, 4)) / 100.0)
            ) AS TotalWeightedScore,
            COUNT(L.log_id) AS TotalLogs
        FROM 
            Viewer V
        JOIN 
            ViewingLog L ON V.viewer_id = L.viewer_id
        JOIN 
            MediaAsset A ON L.asset_id = A.asset_id
        GROUP BY 
            V.viewer_id
    )
    -- 2. Update the Viewer table with the new calculated score
    UPDATE V
    SET V.niche_affinity_score = 
        CASE
            WHEN S.TotalLogs > 0 THEN 
                -- Calculate Average Weighted Score, then multiply by 2.0 to scale the max to ~20.00
                (S.TotalWeightedScore / CAST(S.TotalLogs AS DECIMAL(10, 4))) * 2.0 
            ELSE 
                0.00
        END
    FROM 
        Viewer V
    JOIN 
        ViewerScores S ON V.viewer_id = S.viewer_id;

END
GO

IF OBJECT_ID('usp_CalculateNicheAffinity') IS NOT NULL
    DROP PROCEDURE usp_CalculateNicheAffinity;
GO

CREATE PROCEDURE usp_CalculateNicheAffinity
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Calculate the weighted score for each viewer
    WITH ViewerScores AS (
        SELECT
            V.viewer_id,
            -- FIX: Force intermediate calculation to DECIMAL(10, 4) to preserve precision 
            -- during aggregation (SUM) and division (AVG).
            SUM(
                -- Critical Rating (1-10)
                CAST(L.critical_rating AS DECIMAL(10, 4)) 
                * -- Niche Multiplier (Index/100, e.g., 95/100 = 0.95)
                (CAST(A.popularity_rank_index AS DECIMAL(10, 4)) / 100.0)
            ) AS TotalWeightedScore,
            COUNT(L.log_id) AS TotalLogs
        FROM 
            Viewer V
        JOIN 
            ViewingLog L ON V.viewer_id = L.viewer_id
        JOIN 
            MediaAsset A ON L.asset_id = A.asset_id
        GROUP BY 
            V.viewer_id
    )
    -- 2. Update the Viewer table with the new calculated score
    UPDATE V
    SET V.niche_affinity_score = 
        CASE
            WHEN S.TotalLogs > 0 THEN 
                -- Calculate Average Weighted Score, then multiply by 2.0 to scale the max to ~20.00
                -- The result is implicitly cast to DECIMAL(4, 2) when written to the Viewer table.
                (S.TotalWeightedScore / CAST(S.TotalLogs AS DECIMAL(10, 4))) * 2.0 
            ELSE 
                0.00
        END
    FROM 
        Viewer V
    JOIN 
        ViewerScores S ON V.viewer_id = S.viewer_id;

END
GO

IF OBJECT_ID('usp_CalculateNicheAffinity') IS NOT NULL
    DROP PROCEDURE usp_CalculateNicheAffinity;
GO

CREATE PROCEDURE usp_CalculateNicheAffinity
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Calculate the weighted score for each viewer
    WITH ViewerScores AS (
        SELECT
            V.viewer_id,
            SUM(
                -- Critical Rating (1-10) -> Primary enjoyment factor
                CAST(L.critical_rating AS DECIMAL(10, 4)) 
                * -- Popularity Multiplier (Niche factor: Index / 100.0)
                (CAST(A.popularity_rank_index AS DECIMAL(10, 4)) / CAST(100.0 AS DECIMAL(10, 4)))
                -- FIX: Complexity Multiplier (Complexity factor: Score / 5.0)
                * (CAST(L.complexity_score AS DECIMAL(10, 4)) / CAST(5.0 AS DECIMAL(10, 4)))
            ) AS TotalWeightedScore,
            COUNT(L.log_id) AS TotalLogs
        FROM 
            Viewer V
        JOIN 
            ViewingLog L ON V.viewer_id = L.viewer_id
        JOIN 
            MediaAsset A ON L.asset_id = A.asset_id
        GROUP BY 
            V.viewer_id
    )
    -- 2. Update the Viewer table with the new calculated score
    UPDATE V
    SET V.niche_affinity_score = 
        CASE
            WHEN S.TotalLogs > 0 THEN 
                -- Calculate Average Weighted Score, then multiply by 2.0 to scale the max potential score 
                (S.TotalWeightedScore / CAST(S.TotalLogs AS DECIMAL(10, 4))) * CAST(2.0 AS DECIMAL(10, 4))
            ELSE 
                0.00
        END
    FROM 
        Viewer V
    JOIN 
        ViewerScores S ON V.viewer_id = S.viewer_id;

END
GO
--------------------------------------------------------------------------------
-- FUNCTION: udf_GetSimilarViewers
-- Purpose: Finds the top 5 viewers who share the most high-intensity tag validations.
-- Logic: Compares the target Viewer's high-agreement tags (Intensity >= 4) 
--        against all other viewers.
--------------------------------------------------------------------------------
CREATE FUNCTION udf_GetSimilarViewers (@TargetViewerID INT)
RETURNS TABLE
AS
RETURN
(
    -- 1. Identify the target viewer's strong tag affinities (Intensity 4 or 5)
    WITH TargetAffinities AS (
        SELECT 
            tag_id
        FROM 
            ViewerTagValidation
        WHERE 
            viewer_id = @TargetViewerID AND agreement_intensity >= 4
    )
    -- 2. Find other viewers who share these strong affinities
    SELECT TOP 5
        VTV.viewer_id AS SimilarViewerID,
        -- Count how many strong tags are shared
        COUNT(VTV.tag_id) AS SharedTagCount,
        -- Average intensity they assigned to these shared tags
        AVG(CAST(VTV.agreement_intensity AS DECIMAL(4, 2))) AS AvgSharedIntensity
    FROM 
        ViewerTagValidation VTV
    JOIN 
        TargetAffinities TA ON VTV.tag_id = TA.tag_id
    WHERE 
        VTV.viewer_id <> @TargetViewerID -- Exclude the target viewer
        AND VTV.agreement_intensity >= 4  -- Only consider strong validations for clustering
    GROUP BY 
        VTV.viewer_id
    ORDER BY 
        SharedTagCount DESC, 
        AvgSharedIntensity DESC
);
GO


--------------------------------------------------------------------------------
-- 3. FUNCTION: udf_GetViewerStructuralBias
-- Purpose: Identifies the viewer's top structural preferences (ExpertTags).
-- This powers the "Structural Bias Report" on the user's profile page.
-- Logic: Calculates the average AgreementIntensity for all tags the viewer has 
--        validated, filtering for the tags they agree with most strongly (>= 4).
--------------------------------------------------------------------------------
CREATE FUNCTION udf_GetViewerStructuralBias (@TargetViewerID INT)
RETURNS TABLE
AS
RETURN
(
    SELECT TOP 5
        V.tag_id,
        T.tag_name,
        -- Calculate the average intensity they assigned to this specific tag
        AVG(CAST(V.agreement_intensity AS DECIMAL(4, 2))) AS AverageIntensity,
        -- Count how many times they validated this tag
        COUNT(V.tag_id) AS ValidationCount
    FROM 
        ViewerTagValidation V
    JOIN 
        ExpertTag T ON V.tag_id = T.tag_id
    WHERE 
        V.viewer_id = @TargetViewerID
        -- Only consider strong agreement for bias calculation
        AND V.agreement_intensity >= 4
    GROUP BY 
        V.tag_id, T.tag_name
    ORDER BY 
        AverageIntensity DESC,
        ValidationCount DESC
);
GO


--------------------------------------------------------------------------------
-- 4. FUNCTION: udf_GetCrewAffinitySuggestions
-- Purpose: Finds films by the viewer's favorite directors/writers that they haven't seen.
-- This powers the "Affinity Crew Analysis" and delivers high-value niche discovery.
-- Logic: Finds CrewMembers associated with highly-rated assets, then suggests their other work.
--------------------------------------------------------------------------------
CREATE FUNCTION udf_GetCrewAffinitySuggestions (@TargetViewerID INT)
RETURNS TABLE
AS
RETURN
(
    -- 1. Identify top 5 Directors/Writers the viewer rates highly
    WITH TopCrewAffinities AS (
        SELECT TOP 5
            CC.crew_id,
            AVG(CAST(VL.critical_rating AS DECIMAL(4, 2))) AS AvgHighRating
        FROM 
            ViewingLog VL
        JOIN 
            CrewCredit CC ON VL.asset_id = CC.asset_id
        JOIN 
            CrewRole CR ON CC.role_id = CR.role_id
        WHERE 
            VL.viewer_id = @TargetViewerID
            AND VL.critical_rating >= 8 -- Only focus on high ratings
            -- Only include roles that directly influence style (Director, Writer)
            AND CR.category IN ('Direction', 'Writing')
        GROUP BY 
            CC.crew_id
        ORDER BY 
            AvgHighRating DESC
    ),
    -- 2. Find all assets associated with those Top Crew Members
    AllCrewAssets AS (
        SELECT 
            CC.asset_id,
            TCA.crew_id
        FROM 
            CrewCredit CC
        JOIN 
            TopCrewAffinities TCA ON CC.crew_id = TCA.crew_id
    )
    -- 3. Filter the list to only include assets the target viewer has NOT seen
    SELECT TOP 10
        A.asset_id,
        A.title,
        C.full_name AS CrewMemberName
    FROM 
        AllCrewAssets ACA
    JOIN 
        MediaAsset A ON ACA.asset_id = A.asset_id
    JOIN
        CrewMember C ON ACA.crew_id = C.crew_id
    WHERE 
        ACA.asset_id NOT IN (SELECT asset_id FROM ViewingLog WHERE viewer_id = @TargetViewerID)
    GROUP BY 
        A.asset_id, A.title, C.full_name
    ORDER BY 
        -- Prioritize less popular (more niche) suggestions
        MIN(A.popularity_rank_index) ASC
);
GO


--------------------------------------------------------------------------------
-- 5. FUNCTION: udf_GetNicheRecommendations
-- Purpose: The final, comprehensive recommendation list for the user.
-- This combines Collaborative Filtering (Similar Viewers) and Content-Based Filtering (Tags).
--------------------------------------------------------------------------------
CREATE FUNCTION udf_GetNicheRecommendations (@TargetViewerID INT)
RETURNS TABLE
AS
RETURN
(
    -- ** PART A: Collaborative Filtering (The Similar Viewer Pool) **
    WITH SimilarViewerRecs AS (
        SELECT 
            VL.asset_id,
            -- Calculate a collaborative rating score (Weighted by the similar viewer's niche affinity)
            AVG(CAST(VL.critical_rating AS DECIMAL(4, 2)) * SV.SharedTagCount) AS CollaborativeScore
        FROM 
            udf_GetSimilarViewers(@TargetViewerID) SV
        JOIN 
            ViewingLog VL ON SV.SimilarViewerID = VL.viewer_id
        WHERE 
            VL.critical_rating >= 7 -- Only recommend highly rated films from peers
        GROUP BY 
            VL.asset_id
    ),

    -- ** PART B: Content-Based Filtering (The Viewer's Structural Bias) **
    ContentBiasRecs AS (
        SELECT
            VTV.asset_id,
            -- Calculate a content score based on how many of the user's top tags match the film
            SUM(VTV.agreement_intensity) AS ContentMatchScore
        FROM 
            udf_GetViewerStructuralBias(@TargetViewerID) SB
        JOIN 
            ViewerTagValidation VTV ON SB.tag_id = VTV.tag_id
        WHERE
            VTV.viewer_id = @TargetViewerID -- Use the target viewer's own validated intensity
        GROUP BY 
            VTV.asset_id
    ),
    
    -- ** PART C: Combine and Finalize the Score **
    CombinedRecommendations AS (
        SELECT
            A.asset_id,
            A.title,
            A.popularity_rank_index,
            -- Final Score: Collaborative Score (Weighted 60%) + Content Score (Weighted 40%)
            ISNULL(SVR.CollaborativeScore * 0.6, 0) + ISNULL(CBR.ContentMatchScore * 0.4, 0) AS FinalRecScore
        FROM 
            MediaAsset A
        LEFT JOIN 
            SimilarViewerRecs SVR ON A.asset_id = SVR.asset_id
        LEFT JOIN
            ContentBiasRecs CBR ON A.asset_id = CBR.asset_id
        WHERE
            -- Exclude assets the target viewer has already watched
            A.asset_id NOT IN (SELECT asset_id FROM ViewingLog WHERE viewer_id = @TargetViewerID)
            -- Only consider films that have *some* positive score (either collaborative or content match)
            AND (SVR.asset_id IS NOT NULL OR CBR.asset_id IS NOT NULL)
    )
    
    SELECT TOP 20
        asset_id,
        title,
        -- Calculate the Relatability Score (normalized for the front-end)
        (FinalRecScore / MAX(FinalRecScore) OVER()) * 100 AS RelatabilityScore
    FROM 
        CombinedRecommendations
    ORDER BY 
        FinalRecScore DESC, 
        popularity_rank_index ASC -- Tiebreaker: Prioritize more niche/low index films
);
GO


-- ==============================================================================
-- ANALYTICAL QUERIES SECTION
-- 12+ SELECT Queries with at least 4 queries across multiple tables
-- ==============================================================================

--------------------------------------------------------------------------------
-- QUERY 1: Get all movies rated above 8
--------------------------------------------------------------------------------
SELECT 
    asset_id,
    title,
    release_year,
    budget_level,
    runtime_minutes
FROM 
    MediaAsset
WHERE 
    media_type = 'Movie'
    AND asset_id IN (
        SELECT asset_id 
        FROM ViewingLog 
        WHERE critical_rating >= 8
    );
GO

--------------------------------------------------------------------------------
-- QUERY 2: Find all active viewers with their total viewing count (JOIN - Multiple Tables)
--------------------------------------------------------------------------------
SELECT 
    V.viewer_id,
    V.username,
    V.email,
    V.niche_affinity_score,
    COUNT(VL.log_id) AS TotalViewings,
    AVG(CAST(VL.critical_rating AS DECIMAL(4, 2))) AS AvgRating
FROM 
    Viewer V
LEFT JOIN 
    ViewingLog VL ON V.viewer_id = VL.viewer_id
WHERE 
    V.is_active = 1
GROUP BY 
    V.viewer_id, V.username, V.email, V.niche_affinity_score;
GO

WITH ViewerWeightedData AS (
    SELECT
        V.viewer_id,
        (CAST(L.critical_rating AS DECIMAL(10, 4)) 
            * (CAST(A.popularity_rank_index AS DECIMAL(10, 4)) / CAST(100.0 AS DECIMAL(10, 4)))
            * (CAST(L.complexity_score AS DECIMAL(10, 4)) / CAST(5.0 AS DECIMAL(10, 4)))
        ) AS WeightedScorePerLog
    FROM 
        Viewer V
    JOIN 
        ViewingLog L ON V.viewer_id = L.viewer_id
    JOIN 
        MediaAsset A ON L.asset_id = A.asset_id
),
CalculatedScores AS (
    SELECT
        viewer_id,
        (AVG(WeightedScorePerLog) * CAST(2.0 AS DECIMAL(10, 4))) AS CalculatedNicheAffinity
    FROM 
        ViewerWeightedData
    GROUP BY 
        viewer_id
)
SELECT 
    V.viewer_id,
    V.username,
    V.email,
    -- Live calculated score replaces the stored column reference
    ISNULL(CS.CalculatedNicheAffinity, 0.00) AS niche_affinity_score, 
    COUNT(VL.log_id) AS TotalViewings,
    AVG(CAST(VL.critical_rating AS DECIMAL(4, 2))) AS AvgRating
FROM 
    Viewer V
LEFT JOIN 
    ViewingLog VL ON V.viewer_id = VL.viewer_id
LEFT JOIN
    CalculatedScores CS ON V.viewer_id = CS.viewer_id
WHERE 
    V.is_active = 1
GROUP BY 
    V.viewer_id, V.username, V.email, ISNULL(CS.CalculatedNicheAffinity, 0.00)
ORDER BY 
    V.viewer_id;
GO
--------------------------------------------------------------------------------
-- QUERY 3: List all movies by Christopher Nolan (JOIN - Multiple Tables)
--------------------------------------------------------------------------------
SELECT 
    MA.asset_id,
    MA.title,
    MA.release_year,
    CM.full_name AS DirectorName,
    CR.role_name
FROM 
    MediaAsset MA
JOIN 
    CrewCredit CC ON MA.asset_id = CC.asset_id
JOIN 
    CrewMember CM ON CC.crew_id = CM.crew_id
JOIN 
    CrewRole CR ON CC.role_id = CR.role_id
WHERE 
    CM.full_name = 'Christopher Nolan'
    AND CR.category = 'Direction';
GO

--------------------------------------------------------------------------------
-- QUERY 4: Average ratings by budget level (JOIN - Multiple Tables)
--------------------------------------------------------------------------------
SELECT 
    MA.budget_level,
    COUNT(DISTINCT MA.asset_id) AS TotalMovies,
    AVG(CAST(VL.critical_rating AS DECIMAL(4, 2))) AS AvgRating,
    AVG(CAST(VL.complexity_score AS DECIMAL(4, 2))) AS AvgComplexity
FROM 
    MediaAsset MA
JOIN 
    ViewingLog VL ON MA.asset_id = VL.asset_id
GROUP BY 
    MA.budget_level
ORDER BY 
    AvgRating DESC;
GO

--------------------------------------------------------------------------------
-- QUERY 5: Get all expert tags for a specific movie (JOIN - Multiple Tables)
--------------------------------------------------------------------------------
SELECT 
    MA.title,
    ET.tag_name,
    ET.tag_definition,
    AVG(CAST(VTV.agreement_intensity AS DECIMAL(4, 2))) AS AvgAgreementIntensity,
    COUNT(VTV.viewer_id) AS TotalValidations
FROM 
    MediaAsset MA
JOIN 
    ViewerTagValidation VTV ON MA.asset_id = VTV.asset_id
JOIN 
    ExpertTag ET ON VTV.tag_id = ET.tag_id
WHERE 
    MA.title = 'The Lighthouse'
GROUP BY 
    MA.title, ET.tag_name, ET.tag_definition;
GO

--------------------------------------------------------------------------------
-- QUERY 6: Find viewers who rated indie movies highly
--------------------------------------------------------------------------------
SELECT 
    V.viewer_id,
    V.username,
    COUNT(VL.log_id) AS IndieMoviesWatched,
    AVG(CAST(VL.critical_rating AS DECIMAL(4, 2))) AS AvgIndieRating
FROM 
    Viewer V
JOIN 
    ViewingLog VL ON V.viewer_id = VL.viewer_id
JOIN 
    MediaAsset MA ON VL.asset_id = MA.asset_id
WHERE 
    MA.budget_level = 'Indie'
GROUP BY 
    V.viewer_id, V.username
HAVING 
    AVG(CAST(VL.critical_rating AS DECIMAL(4, 2))) >= 8;
GO

--------------------------------------------------------------------------------
-- QUERY 7: Get most popular expert tags across all movies
--------------------------------------------------------------------------------
SELECT 
    ET.tag_id,
    ET.tag_name,
    ET.tag_definition,
    COUNT(VTV.viewer_id) AS TotalValidations,
    AVG(CAST(VTV.agreement_intensity AS DECIMAL(4, 2))) AS AvgIntensity
FROM 
    ExpertTag ET
JOIN 
    ViewerTagValidation VTV ON ET.tag_id = VTV.tag_id
GROUP BY 
    ET.tag_id, ET.tag_name, ET.tag_definition
ORDER BY 
    TotalValidations DESC;
GO

--------------------------------------------------------------------------------
-- QUERY 8: List all crew members and their primary roles
--------------------------------------------------------------------------------
SELECT 
    CM.crew_id,
    CM.full_name,
    CM.primary_role,
    COUNT(DISTINCT CC.asset_id) AS TotalProjects,
    STRING_AGG(CR.role_name, ', ') AS AllRoles
FROM 
    CrewMember CM
LEFT JOIN 
    CrewCredit CC ON CM.crew_id = CC.crew_id
LEFT JOIN 
    CrewRole CR ON CC.role_id = CR.role_id
GROUP BY 
    CM.crew_id, CM.full_name, CM.primary_role;
GO

--------------------------------------------------------------------------------
-- QUERY 9: Find movies released after 2015 with high complexity scores
--------------------------------------------------------------------------------
SELECT 
    MA.asset_id,
    MA.title,
    MA.release_year,
    AVG(CAST(VL.complexity_score AS DECIMAL(4, 2))) AS AvgComplexity,
    AVG(CAST(VL.critical_rating AS DECIMAL(4, 2))) AS AvgRating,
    COUNT(VL.viewer_id) AS TotalViewers
FROM 
    MediaAsset MA
JOIN 
    ViewingLog VL ON MA.asset_id = VL.asset_id
WHERE 
    MA.release_year >= 2015
GROUP BY 
    MA.asset_id, MA.title, MA.release_year
HAVING 
    AVG(CAST(VL.complexity_score AS DECIMAL(4, 2))) >= 4
ORDER BY 
    AvgComplexity DESC;
GO

--------------------------------------------------------------------------------
-- QUERY 10: Get viewer engagement by join year
--------------------------------------------------------------------------------
SELECT 
    YEAR(V.joined_date) AS JoinYear,
    COUNT(V.viewer_id) AS TotalViewers,
    AVG(V.niche_affinity_score) AS AvgNicheScore,
    SUM(CASE WHEN VL.viewer_id IS NOT NULL THEN 1 ELSE 0 END) AS ActiveViewers
FROM 
    Viewer V
LEFT JOIN 
    ViewingLog VL ON V.viewer_id = VL.viewer_id
GROUP BY 
    YEAR(V.joined_date)
ORDER BY 
    JoinYear DESC;
GO

WITH ViewerWeightedData AS (
    -- Calculate the weighted score for every single viewing log entry
    SELECT
        V.viewer_id,
        (CAST(L.critical_rating AS DECIMAL(10, 4)) 
            * (CAST(A.popularity_rank_index AS DECIMAL(10, 4)) / CAST(100.0 AS DECIMAL(10, 4)))
            * (CAST(L.complexity_score AS DECIMAL(10, 4)) / CAST(5.0 AS DECIMAL(10, 4)))
        ) AS WeightedScorePerLog
    FROM 
        Viewer V
    JOIN 
        ViewingLog L ON V.viewer_id = L.viewer_id
    JOIN 
        MediaAsset A ON L.asset_id = A.asset_id
),
CalculatedScores AS (
    -- Calculate the final Niche Affinity Score for each viewer by averaging their weighted logs
    SELECT
        viewer_id,
        -- Scale the final average by 2.0 to match the original scoring range
        (AVG(WeightedScorePerLog) * CAST(2.0 AS DECIMAL(10, 4))) AS CalculatedNicheAffinity
    FROM 
        ViewerWeightedData
    GROUP BY 
        viewer_id
)
SELECT 
    YEAR(V.joined_date) AS JoinYear,
    COUNT(V.viewer_id) AS TotalViewers,
    -- Use the live calculated score from the CTE
    AVG(CS.CalculatedNicheAffinity) AS AvgNicheScore,
    -- Count distinct viewers who have at least one viewing log
    COUNT(DISTINCT VL.viewer_id) AS ActiveViewers
FROM 
    Viewer V
LEFT JOIN 
    ViewingLog VL ON V.viewer_id = VL.viewer_id
LEFT JOIN
    CalculatedScores CS ON V.viewer_id = CS.viewer_id
GROUP BY 
    YEAR(V.joined_date)
ORDER BY 
    JoinYear DESC;
GO
--------------------------------------------------------------------------------
-- QUERY 11: Find all acting roles in blockbuster movies (JOIN - Multiple Tables)
--------------------------------------------------------------------------------
SELECT 
    MA.title,
    CM.full_name AS ActorName,
    CR.role_name,
    MA.release_year,
    MA.budget_level
FROM 
    MediaAsset MA
JOIN 
    CrewCredit CC ON MA.asset_id = CC.asset_id
JOIN 
    CrewMember CM ON CC.crew_id = CM.crew_id
JOIN 
    CrewRole CR ON CC.role_id = CR.role_id
WHERE 
    MA.budget_level = 'Blockbuster'
    AND CR.category = 'Acting'
ORDER BY 
    MA.release_year DESC;
GO

--------------------------------------------------------------------------------
-- QUERY 12: Get detailed viewer profile with statistics (JOIN - Multiple Tables)
--------------------------------------------------------------------------------
SELECT 
    V.viewer_id,
    V.username,
    V.email,
    V.niche_affinity_score,
    COUNT(DISTINCT VL.asset_id) AS UniqueMoviesWatched,
    AVG(CAST(VL.critical_rating AS DECIMAL(4, 2))) AS AvgRating,
    AVG(CAST(VL.complexity_score AS DECIMAL(4, 2))) AS AvgComplexityPreference,
    COUNT(DISTINCT VTV.tag_id) AS UniqueTagsValidated,
    MAX(VL.rating_timestamp) AS LastActivityDate
FROM 
    Viewer V
LEFT JOIN 
    ViewingLog VL ON V.viewer_id = VL.viewer_id
LEFT JOIN 
    ViewerTagValidation VTV ON V.viewer_id = VTV.viewer_id
WHERE 
    V.is_active = 1
GROUP BY 
    V.viewer_id, V.username, V.email, V.niche_affinity_score;
GO

--------------------------------------------------------------------------------
-- QUERY 13: Movies with the most tag validations (JOIN - Multiple Tables)
--------------------------------------------------------------------------------
SELECT 
    MA.asset_id,
    MA.title,
    MA.release_year,
    MA.budget_level,
    COUNT(DISTINCT VTV.tag_id) AS UniqueTags,
    COUNT(VTV.viewer_id) AS TotalValidations,
    AVG(CAST(VTV.agreement_intensity AS DECIMAL(4, 2))) AS AvgIntensity
FROM 
    MediaAsset MA
JOIN 
    ViewerTagValidation VTV ON MA.asset_id = VTV.asset_id
GROUP BY 
    MA.asset_id, MA.title, MA.release_year, MA.budget_level
ORDER BY 
    TotalValidations DESC;
GO

--------------------------------------------------------------------------------
-- QUERY 14: Find crew members who work across multiple budget levels
--------------------------------------------------------------------------------
SELECT 
    CM.crew_id,
    CM.full_name,
    CM.primary_role,
    COUNT(DISTINCT MA.budget_level) AS BudgetLevelsDiversity,
    STRING_AGG(DISTINCT MA.budget_level, ', ') AS BudgetLevels,
    COUNT(DISTINCT CC.asset_id) AS TotalProjects
FROM 
    CrewMember CM
JOIN 
    CrewCredit CC ON CM.crew_id = CC.crew_id
JOIN 
    MediaAsset MA ON CC.asset_id = MA.asset_id
GROUP BY 
    CM.crew_id, CM.full_name, CM.primary_role
HAVING 
    COUNT(DISTINCT MA.budget_level) > 1
ORDER BY 
    BudgetLevelsDiversity DESC;
GO
--------------------------------------------------------------------------------
--QUERY 15: Personalized 'next watch' recommendations for all active viewers
--------------------------------------------------------------------------------
WITH ViewerWeightedData AS (
    -- Standard calculation for individual log weights
    SELECT
        V.viewer_id,
        (CAST(L.critical_rating AS DECIMAL(10, 4)) 
            * (CAST(A.popularity_rank_index AS DECIMAL(10, 4)) / CAST(100.0 AS DECIMAL(10, 4)))
            * (CAST(L.complexity_score AS DECIMAL(10, 4)) / CAST(5.0 AS DECIMAL(10, 4)))
        ) AS WeightedScorePerLog
    FROM 
        Viewer V
    JOIN 
        ViewingLog L ON V.viewer_id = L.viewer_id
    JOIN 
        MediaAsset A ON L.asset_id = A.asset_id
),
LiveNicheScores AS (
    -- Calculate the final Niche Affinity Score for each viewer
    SELECT
        viewer_id,
        (AVG(WeightedScorePerLog) * CAST(2.0 AS DECIMAL(10, 4))) AS CalculatedNicheAffinity
    FROM 
        ViewerWeightedData
    GROUP BY 
        viewer_id
),
-- This CTE uses the recommendation function to get the TOP 1 suggestion per viewer
NextWatchRecommendations AS (
    SELECT
        V.viewer_id,
        -- Apply the recommendation function and extract the best title using a subquery
        (SELECT TOP 1 title FROM udf_GetNicheRecommendations(V.viewer_id) ORDER BY RelatabilityScore DESC) AS next_watch_title
    FROM 
        Viewer V
)
-- Final Select Statement combining the Viewer, their Live Score, and their Top Recommendation
SELECT
    V.viewer_id,
    V.username AS viewer_profile_name,
    ISNULL(LNS.CalculatedNicheAffinity, 0.00) AS viewer_niche_aff_score,
    ISNULL(NWR.next_watch_title, 'No Recommendation Found (Profile Incomplete)') AS next_watch
FROM
    Viewer V
LEFT JOIN
    LiveNicheScores LNS ON V.viewer_id = LNS.viewer_id
LEFT JOIN
    NextWatchRecommendations NWR ON V.viewer_id = NWR.viewer_id
ORDER BY
    viewer_niche_aff_score DESC;
GO

WITH ViewerWeightedData AS (
    -- Standard calculation for individual log weights
    SELECT
        V.viewer_id,
        (CAST(L.critical_rating AS DECIMAL(10, 4)) 
            * (CAST(A.popularity_rank_index AS DECIMAL(10, 4)) / CAST(100.0 AS DECIMAL(10, 4)))
            * (CAST(L.complexity_score AS DECIMAL(10, 4)) / CAST(5.0 AS DECIMAL(10, 4)))
        ) AS WeightedScorePerLog
    FROM 
        Viewer V
    JOIN 
        ViewingLog L ON V.viewer_id = L.viewer_id
    JOIN 
        MediaAsset A ON L.asset_id = A.asset_id
    WHERE
        -- Restrict data to the four target users
        V.username IN ('jurgensieck', 'omaima', 'mikedanial', 'sons')
),
LiveNicheScores AS (
    -- Calculate the final Niche Affinity Score for each viewer
    SELECT
        viewer_id,
        (AVG(WeightedScorePerLog) * CAST(2.0 AS DECIMAL(10, 4))) AS CalculatedNicheAffinity
    FROM 
        ViewerWeightedData
    GROUP BY 
        viewer_id
),
-- This CTE uses the recommendation function to get the TOP 1 suggestion per viewer
NextWatchRecommendations AS (
    SELECT
        V.viewer_id,
        -- Apply the recommendation function and extract the best title using a subquery
        (SELECT TOP 1 title FROM udf_GetNicheRecommendations(V.viewer_id) ORDER BY RelatabilityScore DESC) AS next_watch_title
    FROM 
        Viewer V
    WHERE
        V.username IN ('jurgensieck', 'omaima', 'mikedanial', 'sons')
)
-- Final Select Statement combining the Viewer, their Live Score, their Hardcoded Persona, and their Top Recommendation
SELECT
    V.viewer_id,
    V.username AS viewer_profile_name,
    ISNULL(LNS.CalculatedNicheAffinity, 0.00) AS viewer_niche_aff_score,
    -- Hardcode the specific persona names requested by the user
    CASE V.username
        WHEN 'jurgensieck' THEN 'The Temporal Disputor'
        WHEN 'omaima' THEN 'The Absolute Intensivist'
        WHEN 'mikedanial' THEN 'The Subtext Seeker'
        WHEN 'sons' THEN 'The Aesthetic Choreographer'
        ELSE 'Unknown Persona' 
    END AS viewer_persona,
    ISNULL(NWR.next_watch_title, 'No Recommendation Found (Profile Incomplete)') AS next_watch
FROM
    Viewer V
LEFT JOIN
    LiveNicheScores LNS ON V.viewer_id = LNS.viewer_id
LEFT JOIN
    NextWatchRecommendations NWR ON V.viewer_id = NWR.viewer_id
WHERE
    V.username IN ('jurgensieck', 'omaima', 'mikedanial', 'sons')
ORDER BY
    viewer_niche_aff_score DESC;
GO

WITH ViewerWeightedData AS (
    -- Standard calculation for individual log weights
    SELECT
        V.viewer_id,
        (CAST(L.critical_rating AS DECIMAL(10, 4)) 
            * (CAST(A.popularity_rank_index AS DECIMAL(10, 4)) / CAST(100.0 AS DECIMAL(10, 4)))
            * (CAST(L.complexity_score AS DECIMAL(10, 4)) / CAST(5.0 AS DECIMAL(10, 4)))
        ) AS WeightedScorePerLog
    FROM 
        Viewer V
    JOIN 
        ViewingLog L ON V.viewer_id = L.viewer_id
    JOIN 
        MediaAsset A ON L.asset_id = A.asset_id
    WHERE
        -- Restrict data to the four target users
        V.username IN ('jurgensieck', 'omaima', 'mikedanial', 'sons')
),
LiveNicheScores AS (
    -- Calculate the final Niche Affinity Score for each viewer
    SELECT
        viewer_id,
        (AVG(WeightedScorePerLog) * CAST(2.0 AS DECIMAL(10, 4))) AS CalculatedNicheAffinity
    FROM 
        ViewerWeightedData
    GROUP BY 
        viewer_id
)
-- Final Select Statement combining the Viewer, their Live Score, their Hardcoded Persona, and their Hardcoded Recommendation
SELECT
    V.viewer_id,
    V.username AS viewer_profile_name,
    ISNULL(LNS.CalculatedNicheAffinity, 0.00) AS viewer_niche_aff_score,
    -- Hardcode the specific persona names requested by the user
    CASE V.username
        WHEN 'jurgensieck' THEN 'The Temporal Disputor'
        WHEN 'omaima' THEN 'The Absolute Intensivist'
        WHEN 'mikedanial' THEN 'The Subtext Seeker'
        WHEN 'sons' THEN 'The Aesthetic Choreographer'
        ELSE 'Unknown Persona' 
    END AS viewer_persona,
    -- Hardcode the specific movie recommendations requested by the user
    CASE V.username
        WHEN 'jurgensieck' THEN 'Primer'
        WHEN 'omaima' THEN 'The Wailing'
        WHEN 'mikedanial' THEN 'Donnie Darko'
        WHEN 'sons' THEN '1917'
        ELSE 'No Recommendation Found' 
    END AS next_watch
FROM
    Viewer V
LEFT JOIN
    LiveNicheScores LNS ON V.viewer_id = LNS.viewer_id
WHERE
    V.username IN ('jurgensieck', 'omaima', 'mikedanial', 'sons')
ORDER BY
    viewer_niche_aff_score DESC;
GO
-- End of sql/file2.sql