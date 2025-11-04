CREATE DATABASE DB_Prog
use DB_Prog


CREATE TABLE Viewer(
    Viewer_id int PRIMARY KEY IDENTITY,
    User_name VARCHAR(255),
    Email VARCHAR(255),
    date_joined VARCHAR(255),
    is_available BIT
    --NicheAffScore 
);

CREATE TABLE Media(
    Media_id int PRIMARY KEY IDENTITY,
    Title VARCHAR(255),
    Release_Year DATE,
    Run_Time TIME,
    Budget_level INT,
    --popularity_index
);

CREATE TABLE CrewMember(
    Crew_id int PRIMARY KEY IDENTITY,
    First_Name VARCHAR(255),
    Last_Name VARCHAR(255),
    Role varchar(255)
);

CREATE Table ExperTag (
    Tag_id int PRIMARY KEY IDENTITY,
    Tag_Name VARCHAR(255),
    --TagDefinition
);

CREATE TABLE ViewingLog(
    Log_id int PRIMARY KEY IDENTITY, 
    Viewer_id int , 
    Media_id int , 
    DateWatched DATE, 
    Comments VARCHAR(255), 
   -- CriticalRating (calc), 
   -- ComplexityScore (calc)
   FOREIGN KEY (Viewer_id) REFERENCES Viewer(Viewer_id),
   FOREIGN KEY (Media_id) REFERENCES Media(Media_id)
);

CREATE TABLE CrewCredit(
    Crew_id int, 
    Media_id int, 
    IsPrimaryCredit BIT
    PRIMARY KEY(Crew_id,Media_id),
    FOREIGN KEY(Crew_id)REFERENCES CrewMember(Crew_id),
    FOREIGN KEY(Media_id)REFERENCES Media(Media_id),
);

CREATE TABLE ViewerTagValidation(
    Viewer_id int,
    Media_id int, 
    Tag_id int, 
    ValidationDate DATE, 
   -- AgreementIntensity (calc)
   PRIMARY KEY(Viewer_id, Media_id, Tag_id),
   FOREIGN KEY(Viewer_id)REFERENCES Viewer(Viewer_id),
   FOREIGN KEY(Media_id)REFERENCES Media(Media_id),
   FOREIGN KEY(Tag_id)REFERENCES ExperTag(Tag_id),
);