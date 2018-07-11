--- miscellaneous notes ---
--Created Model with:
--script/tvdx_create.pl model DB DBIC::Schema tvdx::Schema create=static components=TimeStamp dbi:SQLite:tvdx.db on_connect_do="PRAGMA foreign_keys = ON"

--- database notes ---

-- commands to add tuners are:
-- insert into tuner (tuner_id,latitude,longitude,owner_id,start_date) values ('DEADBEEF',45,-90,'Climax, MI',datetime());
-- insert into tuner_number(tuner_id,tuner_number,description,start_date) values ('DEADBEEF','tuner0','25 foot dish aimed at Kalamazoo',datetime());
-- insert into tuner_number(tuner_id,tuner_number,description,start_date) values ('DEADBEEF','tuner1','Rabbit Ears in basement',datetime());

--- commands to create database.  Run sqlite11 tvdx.db and paste in the below:

--PRAGMA foreign_keys = ON;
--
-- Information for the HDHomeRun unit sending signal reports
--
use tvdx;
CREATE TABLE tuner (
  tuner_id VARCHAR(255) NOT NULL PRIMARY KEY,
  latitude FLOAT(11,8) NOT NULL,
  longitude FLOAT(11,8) NOT NULL,
  owner_id VARCHAR(255) NOT NULL,
  start_date DATETIME NOT NULL,
  end_date DATETIME
);
--
-- Information on the individual tuners used.
--
CREATE TABLE tuner_number (
tuner_number_key INTEGER NOT NULL PRIMARY KEY,
tuner_id VARCHAR(255) NOT NULL,
tuner_number VARCHAR(255) NOT NULL,
description VARCHAR(255) NOT NULL,
start_date DATETIME NOT NULL,
end_date DATETIME,
FOREIGN KEY(tuner_id) REFERENCES tuner(tuner_id)
);
--
-- Information from the fcc website
--
CREATE TABLE fcc (
  callsign VARCHAR(255) NOT NULL PRIMARY KEY,
  rf_channel INTEGER NOT NULL,
  latitude FLOAT(11,8) NOT NULL,
  longitude FLOAT(11,8) NOT NULL,
  start_date DATETIME NOT NULL,
  end_date DATETIME,
  virtual_channel FLOAT(11,8) NOT NULL,
  city_state VARCHAR(255) NOT NULL,
  erp_kw VARCHAR(255) NOT NULL,
  rcamsl VARCHAR(255) NOT NULL,
  last_fcc_lookup DATETIME NOT NULL
);
--
-- Copy of TSID query from rabbitears.info.  Avoids hammering the server
--
CREATE TABLE rabbitears_tsid (
  re_tsid_key INTEGER NOT NULL PRIMARY KEY,
  tsid INTEGER NOT NULL,
  re_rval VARCHAR(255),
  last_re_lookup DATETIME NOT NULL
);
--
-- Copy of CALL query from rabbitears.info.  Avoids hammering the server
--
CREATE TABLE rabbitears_call (
  re_call_key INTEGER NOT NULL PRIMARY KEY,
  callsign VARCHAR(255) NOT NULL,
  re_rval VARCHAR(255),
  last_re_lookup DATETIME NOT NULL
);
--
-- Most recent Reports from tuners when a signal is detected
--
CREATE TABLE signal_report (
  signal_key INTEGER NOT NULL PRIMARY KEY,
  rx_date DATETIME NOT NULL,
  first_rx_date DATETIME NOT NULL,
  rf_channel INTEGER NOT NULL,
  strength FLOAT(11,8) NOT NULL,
  sig_noise FLOAT(11,8) NOT NULL,
  tuner_id VARCHAR(255) NOT NULL,
  tuner_number VARCHAR(255) NOT NULL,
  callsign VARCHAR(255) NOT NULL,
  virtual_channel FLOAT(11,8) NOT NULL,
  FOREIGN KEY(tuner_id) REFERENCES tuner(tuner_id),
  FOREIGN KEY(callsign) REFERENCES fcc(callsign)
);
--
-- TSID received from a station
--
CREATE TABLE tsid (
  tsid_key INTEGER NOT NULL PRIMARY KEY,
  rx_date DATETIME NOT NULL,
  tsid INTEGER NOT NULL,
  callsign VARCHAR(255) NOT NULL,
  FOREIGN KEY(callsign) REFERENCES fcc(callsign)
);
--
-- Virtual channels received in PSIP
--
CREATE TABLE psip_virtual (
  virtual_key INTEGER NOT NULL PRIMARY KEY,
  rx_date DATETIME NOT NULL,
  name VARCHAR(255) NOT NULL,
  channel VARCHAR(255) NOT NULL,
  callsign VARCHAR(255) NOT NULL,
  FOREIGN KEY(callsign) REFERENCES fcc(callsign)
);
