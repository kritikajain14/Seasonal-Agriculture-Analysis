-- ============================================================
-- Seasonal Agriculture Performance Analysis — SQL Queries
-- Works in MySQL / PostgreSQL / SQL Server with minor tweaks
-- Import seasonal_agriculture_performance_dataset.csv as table: farm_data
-- ============================================================

-- 1. TABLE SETUP (adjust types as needed for your RDBMS)
CREATE TABLE farm_data (
    Farm_ID VARCHAR(20),
    State VARCHAR(50),
    District VARCHAR(50),
    Crop VARCHAR(30),
    Season VARCHAR(10),
    Farm_Area_Hectares DECIMAL(6,2),
    Rainfall_mm DECIMAL(7,2),
    Avg_Temperature_C DECIMAL(5,2),
    Humidity_pct DECIMAL(5,2),
    Sunlight_Hours_Day DECIMAL(4,2),
    Soil_pH DECIMAL(4,2),
    Soil_Moisture_pct DECIMAL(5,2),
    Nitrogen_kg_ha DECIMAL(6,2),
    Phosphorus_kg_ha DECIMAL(6,2),
    Potassium_kg_ha DECIMAL(6,2),
    Irrigation_Method VARCHAR(20),
    Fertilizer_kg_ha DECIMAL(6,2),
    Pesticide_Litre_ha DECIMAL(5,2),
    Seed_Quality_Score DECIMAL(4,2),
    Yield_Tonnes_Ha DECIMAL(7,2),
    Production_Tonnes DECIMAL(8,2),
    Market_Price_INR_Tonne INT,
    Total_Cost_INR INT,
    Revenue_INR INT,
    Profit_INR INT,
    Water_Used_m3 INT,
    Water_Efficiency_t_per_1000m3 DECIMAL(6,3),
    Disease_Pest_Risk_pct DECIMAL(5,2)
);

-- Load data (MySQL example — adjust path/permissions):
-- LOAD DATA INFILE 'seasonal_agriculture_performance_dataset.csv'
-- INTO TABLE farm_data
-- FIELDS TERMINATED BY ',' ENCLOSED BY '"'
-- LINES TERMINATED BY '\n'
-- IGNORE 1 ROWS;

-- ============================================================
-- 2. DATA QUALITY CHECKS
-- ============================================================

-- Missing values per column that commonly has nulls
SELECT
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(Rainfall_mm)      AS missing_rainfall,
    COUNT(*) - COUNT(Soil_Moisture_pct) AS missing_soil_moisture,
    COUNT(*) - COUNT(Yield_Tonnes_Ha)   AS missing_yield
FROM farm_data;

-- Duplicate Farm_ID check
SELECT Farm_ID, COUNT(*) AS cnt
FROM farm_data
GROUP BY Farm_ID
HAVING COUNT(*) > 1;

-- ============================================================
-- 3. SEASONAL PERFORMANCE SUMMARY
-- ============================================================

SELECT
    Season,
    COUNT(*) AS num_farms,
    ROUND(AVG(Rainfall_mm), 1)              AS avg_rainfall_mm,
    ROUND(AVG(Avg_Temperature_C), 1)        AS avg_temp_c,
    ROUND(AVG(Yield_Tonnes_Ha), 2)          AS avg_yield_t_ha,
    ROUND(AVG(Total_Cost_INR), 0)           AS avg_cost_inr,
    ROUND(AVG(Revenue_INR), 0)              AS avg_revenue_inr,
    ROUND(AVG(Profit_INR), 0)               AS avg_profit_inr,
    ROUND(AVG(Water_Efficiency_t_per_1000m3), 2) AS avg_water_efficiency,
    ROUND(AVG(Disease_Pest_Risk_pct), 1)    AS avg_disease_risk_pct,
    ROUND(100.0 * SUM(CASE WHEN Profit_INR < 0 THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_loss_making
FROM farm_data
GROUP BY Season
ORDER BY avg_profit_inr DESC;

-- ============================================================
-- 4. CROP PERFORMANCE BY SEASON (pivot-style using conditional aggregation)
-- ============================================================

SELECT
    Crop,
    ROUND(AVG(CASE WHEN Season = 'Kharif' THEN Profit_INR END), 0) AS avg_profit_kharif,
    ROUND(AVG(CASE WHEN Season = 'Rabi'   THEN Profit_INR END), 0) AS avg_profit_rabi,
    ROUND(AVG(CASE WHEN Season = 'Zaid'   THEN Profit_INR END), 0) AS avg_profit_zaid
FROM farm_data
GROUP BY Crop
ORDER BY avg_profit_kharif DESC;

-- ============================================================
-- 5. IRRIGATION METHOD EFFECTIVENESS BY SEASON
-- ============================================================

SELECT
    Irrigation_Method,
    Season,
    ROUND(AVG(Water_Efficiency_t_per_1000m3), 2) AS avg_water_efficiency,
    ROUND(AVG(Water_Used_m3), 0)                 AS avg_water_used_m3,
    ROUND(AVG(Yield_Tonnes_Ha), 2)                AS avg_yield_t_ha
FROM farm_data
GROUP BY Irrigation_Method, Season
ORDER BY Season, avg_water_efficiency DESC;

-- ============================================================
-- 6. STATE-WISE SEASONAL PROFIT PATTERNS
-- ============================================================

SELECT
    State,
    Season,
    ROUND(AVG(Profit_INR), 0) AS avg_profit_inr,
    RANK() OVER (PARTITION BY Season ORDER BY AVG(Profit_INR) DESC) AS profit_rank_in_season
FROM farm_data
GROUP BY State, Season
ORDER BY Season, profit_rank_in_season;

-- ============================================================
-- 7. TOP & BOTTOM PERFORMING FARMS PER SEASON (window functions)
-- ============================================================

WITH ranked_farms AS (
    SELECT
        Farm_ID, State, Crop, Season, Profit_INR,
        RANK() OVER (PARTITION BY Season ORDER BY Profit_INR DESC) AS rank_top,
        RANK() OVER (PARTITION BY Season ORDER BY Profit_INR ASC)  AS rank_bottom
    FROM farm_data
)
SELECT * FROM ranked_farms WHERE rank_top <= 5 OR rank_bottom <= 5
ORDER BY Season, rank_top;

-- ============================================================
-- 8. RESOURCE USAGE COMPARISON ACROSS SEASONS
-- ============================================================

SELECT
    Season,
    ROUND(AVG(Fertilizer_kg_ha), 1)   AS avg_fertilizer,
    ROUND(AVG(Pesticide_Litre_ha), 2) AS avg_pesticide,
    ROUND(AVG(Water_Used_m3), 0)      AS avg_water_used,
    ROUND(AVG(Nitrogen_kg_ha + Phosphorus_kg_ha + Potassium_kg_ha), 1) AS avg_total_npk
FROM farm_data
GROUP BY Season;

-- ============================================================
-- 9. DISEASE/PEST RISK vs HUMIDITY (relationship check)
-- ============================================================

SELECT
    Season,
    CASE
        WHEN Humidity_pct < 50 THEN 'Low (<50%)'
        WHEN Humidity_pct < 70 THEN 'Medium (50-70%)'
        ELSE 'High (>70%)'
    END AS humidity_band,
    ROUND(AVG(Disease_Pest_Risk_pct), 1) AS avg_disease_risk,
    COUNT(*) AS num_farms
FROM farm_data
GROUP BY Season, humidity_band
ORDER BY Season, humidity_band;
