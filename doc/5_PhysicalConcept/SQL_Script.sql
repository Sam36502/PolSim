###################
# Create Database #
###################

CREATE DATABASE `db_PolSim` DEFAULT CHARSET utf8;


#################
# Create Tables #
#################

CREATE TABLE `vote` (
    ID_vote INT NOT NULL UNIQUE AUTO_INCREMENT,
    voter_person_ID INT NOT NULL,
    applied_decision_ID INT NOT NULL,
    agreement BOOLEAN NOT NULL
);

CREATE TABLE `person` (
    ID_person INT NOT NULL UNIQUE AUTO_INCREMENT,
    username VARCHAR(50) NOT NULL UNIQUE,
    passwordhash VARCHAR(255) NOT NULL,
    member_group_ID INT NOT NULL,
    power INT NOT NULL DEFAULT 100
);

CREATE TABLE `group` (
    ID_group INT NOT NULL UNIQUE AUTO_INCREMENT,
    groupname VARCHAR(50) NOT NULL UNIQUE,
    leader_person_ID INT,
    power INT NOT NULL DEFAULT 100,
    parent_group_ID INT
);

CREATE TABLE `decision` (
    ID_decision INT NOT NULL UNIQUE AUTO_INCREMENT,
    title VARCHAR(100) NOT NULL,
    creator_person_ID INT NOT NULL,
    close_time TIMESTAMP NOT NULL,
    voting_group_ID INT NOT NULL,
    creation_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP()
);

CREATE TABLE `action` (
    ID_action INT NOT NULL UNIQUE AUTO_INCREMENT,
    approval_decision_ID INT NOT NULL,
    description VARCHAR(255) NOT NULL,
    exec_time TIMESTAMP NOT NULL
);

CREATE TABLE `command` (
    ID_command INT NOT NULL UNIQUE AUTO_INCREMENT,
    executing_action_ID INT NOT NULL,
    sql_command VARCHAR(255) NOT NULL
);

CREATE TABLE `argument` (
    ID_argument INT NOT NULL UNIQUE AUTO_INCREMENT,
    applying_command_ID INT NOT NULL,
    value INT NOT NULL,
    position INT NOT NULL
);


###################
# Add Constraints #
###################

ALTER TABLE `person` ADD CONSTRAINT
    FOREIGN KEY (member_group_ID)
    REFERENCES `group`(ID_group)
    ON UPDATE CASCADE
    ON DELETE CASCADE;

ALTER TABLE `group` ADD CONSTRAINT
    FOREIGN KEY (parent_group_ID)
    REFERENCES `group`(ID_group)
    ON UPDATE CASCADE
    ON DELETE CASCADE;

ALTER TABLE `group` ADD CONSTRAINT
    FOREIGN KEY (leader_person_ID)
    REFERENCES `person`(ID_person)
    ON UPDATE CASCADE
    ON DELETE CASCADE;

ALTER TABLE `vote` ADD CONSTRAINT
    FOREIGN KEY (voter_person_ID)
    REFERENCES `person`(ID_person)
    ON UPDATE CASCADE
    ON DELETE CASCADE;

ALTER TABLE `vote` ADD CONSTRAINT
    FOREIGN KEY (applied_decision_ID)
    REFERENCES `decision`(ID_decision)
    ON UPDATE CASCADE
    ON DELETE CASCADE;

ALTER TABLE `decision` ADD CONSTRAINT
    FOREIGN KEY (creator_person_ID)
    REFERENCES `person`(ID_person)
    ON UPDATE CASCADE
    ON DELETE CASCADE;

ALTER TABLE `action` ADD CONSTRAINT
    FOREIGN KEY (approval_decision_ID)
    REFERENCES `decision`(ID_decision)
    ON UPDATE CASCADE
    ON DELETE CASCADE;

ALTER TABLE `command` ADD CONSTRAINT
    FOREIGN KEY (executing_action_ID)
    REFERENCES `action`(ID_action)
    ON UPDATE CASCADE
    ON DELETE CASCADE;

ALTER TABLE `argument` ADD CONSTRAINT
    FOREIGN KEY (applying_command_ID)
    REFERENCES `command`(ID_command)
    ON UPDATE CASCADE
    ON DELETE CASCADE;


################
# Create Views #
################

CREATE VIEW v_user_groups AS
    SELECT username, groupname FROM `person` JOIN `group` ON
    member_group_ID = ID_group;

CREATE VIEW v_decision_results AS
    SELECT title,
        (SELECT 0 + SUM(p.power) + SUM(g.power) FROM vote
	    JOIN `person` p ON voter_person_ID = ID_person
            JOIN `group` g ON voter_group_ID = ID_group
            WHERE applied_decision_ID = d.ID_decision
            AND (member_group_ID = d.voting_group_ID OR parent_group_ID = d.voting_group_ID)
            AND agreement = true
        ) as `for`,
	(SELECT 0 + SUM(p.power) + SUM(g.power) FROM vote
	    JOIN `person` p ON voter_person_ID = ID_person
            JOIN `group` g ON voter_group_ID = ID_group
            WHERE applied_decision_ID = d.ID_decision
            AND (member_group_ID = d.voting_group_ID OR parent_group_ID = d.voting_group_ID)
            AND agreement = false
        ) as `against`
    FROM `decision` d;


###################
# Create Triggers #
###################

DELIMITER //

CREATE TRIGGER trg_unowned_vote AFTER INSERT ON vote
    FOR EACH ROW
    BEGIN
	IF NEW.voter_person_ID IS NULL
	AND NEW.voter_group_ID IS NULL THEN
	    SIGNAL SQLSTATE '45000';
	END IF;
    END//
    
DELIMITER ;

############################
# Create Stored Procedures #
############################

DELIMITER //

CREATE PROCEDURE stp_compile_command(IN command_ID INT)
BEGIN
	DECLARE num_args INT
    DEFAULT (SELECT COUNT(*) FROM argument WHERE applying_command_ID = command_ID);
    DECLARE arg_i int
    DEFAULT 1;
    
    DECLARE cmd_str VARCHAR(255)
    DEFAULT (SELECT sql_command FROM command WHERE ID_command = command_ID);
    
    WHILE arg_i <= num_args DO
		SET cmd_str = INSERT(cmd_str, INSTR(cmd_str, "?"), 1,
			(SELECT value FROM argument WHERE position = arg_i AND applying_command_ID = command_ID)
        );
		SET arg_i = arg_i + 1;
    END WHILE;
    SELECT cmd_str;
END//

CREATE PROCEDURE stp_even_power(IN group_ID INT)
BEGIN
	DECLARE power INT
    DEFAULT (SELECT COUNT(*) FROM person WHERE member_group_ID = group_ID);
    
    UPDATE person SET power = 100 / power;
END//

DELIMITER ;