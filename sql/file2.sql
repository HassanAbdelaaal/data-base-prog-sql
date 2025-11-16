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