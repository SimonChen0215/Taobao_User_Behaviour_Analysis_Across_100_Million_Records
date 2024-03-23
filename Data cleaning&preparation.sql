DESC user_behavior

SELECT * FROM user_behavior LIMIT 5

-- Data Cleaning & Preprocessing --
-- Alter the column 'timestamp' to 'timestamps'
ALTER TABLE user_behavior CHANGE timestamp timestamps INT(14)
DESC user_behavior

-- Check if there are NULL values in the table
SELECT * FROM user_behavior WHERE user_id IS NULL;
SELECT * FROM user_behavior WHERE item_id IS NULL;
SELECT * FROM user_behavior WHERE category_id IS NULL;
SELECT * FROM user_behavior WHERE behavior_type IS NULL;
SELECT * FROM user_behavior WHERE timestamps IS NULL;
-- After checking, no results returned, which means there are no null values in this table.

-- Duplicates Detection
SELECT user_id,item_id,timestamps,count(*) FROM user_behavior
GROUP BY user_id,item_id,timestamps
HAVING count(*)>1;

-- Duplicates Removal --
-- Give every row an unique id
ALTER TABLE user_behavior ADD id INT FIRST;
SELECT * FROM user_behavior LIMIT 5
ALTER TABLE user_behavior MODIFY id INT PRIMARY KEY auto_increment;

-- Delete duplicates and keep the first one
DELETE user_behavior FROM 
user_behavior,
(
SELECT user_id,item_id,timestamps,min(id) id FROM user_behavior
GROUP BY user_id,item_id,timestamps
HAVING count(*)>1
) t2
WHERE user_behavior.user_id = t2.user_id 
AND user_behavior.item_id = t2.item_id
AND user_behavior.timestamps = t2.timestamps
AND user_behavior.id > t2.id;

-- The data is too large to process, we fetch 11000000 of them to do further investigation.
CREATE TABLE user_behavior_new2 AS
SELECT * FROM user_behavior
ORDER BY id
LIMIT 11000000;
SELECT * FROM user_behavior_new2 LIMIT 100


-- Then we need to transfer the timestamp into readable columns: Date, Time and Hour
-- datetime
ALTER TABLE user_behavior_new2 ADD datetimes TIMESTAMP(0);
UPDATE user_behavior_new2 SET datetimes=FROM_UNIXTIME(timestamps);
SELECT * FROM user_behavior_new2 LIMIT 5;

-- dates/times/hours
ALTER TABLE user_behavior_new2 ADD dates DATE;
ALTER TABLE user_behavior_new2 ADD times TIME;
ALTER TABLE user_behavior_new2 ADD hours INT;
UPDATE user_behavior_new2 SET dates = DATE(datetimes), times = TIME(datetimes), hours = HOUR(datetimes);
DESC user_behavior_new2

-- Outliers Detection & Removal (All datetimes should be between '2017-11-25 00:00:00' and '2017-12-3 23:59:59')
SELECT MAX(datetimes), MIN(datetimes) FROM user_behavior_new2;
DELETE FROM user_behavior_new2
WHERE datetimes < '2017-11-25 00:00:00' OR datetimes > '2017-12-3 23:59:59';

-- Check how many rows of data after preprocessing
SELECT count(1) FROM user_behavior_new2

-- Add primary key constraint and variables
ALTER TABLE user_behavior_new2 MODIFY id INT PRIMARY KEY auto_increment;
DESC user_behavior_new2


