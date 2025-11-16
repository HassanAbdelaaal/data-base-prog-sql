-- ==============================================================================
-- INDEXING STRATEGY FOR CINEMA CATALOG
-- Optimizes JOINs and WHERE clauses used by the 5 analytical functions.
-- ==============================================================================
USE CinemaCatalog_DB;
GO

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