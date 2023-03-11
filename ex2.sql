BEGIN;
-- Create a temporary table to save the current number of copies of each book in each branch.

    CREATE TEMPORARY TABLE Book_Copies_Temp AS (
		SELECT * FROM Book_Copies
	
	);

    SELECT * FROM Book_Copies_Temp;

-- Implement the commands to perform the necessary change to the database schema.

	DROP TABLE Book_Copies;

	CREATE TABLE Book_Copies (
		book_id SERIAL NOT NULL,
		acquisition_date DATE NOT NULL DEFAULT CURRENT_DATE,
		current_condition VARCHAR(255) NOT NULL DEFAULT 'good',
        branch_id INT NOT NULL,

		CONSTRAINT PK_Book_Copies PRIMARY KEY (book_id),
        CONSTRAINT FK_Book_Copies_Branch FOREIGN KEY (branch_id) REFERENCES Library_Branch(branch_id),
		CONSTRAINT Chk_Book_Copies_Current_Condition CHECK (current_condition IN ('fine', 'good', 'fair', 'poor'))
	
	);
	
	CREATE FUNCTION InsertBookCopies() RETURNS VOID AS $$ 
        DECLARE current_copy INT;
		DECLARE book_copy Book_Copies_Temp;
        BEGIN
            FOR book_copy IN SELECT * FROM Book_Copies_Temp LOOP     
				FOR current_copy IN 1..book_copy.no_of_copies LOOP
                	INSERT INTO Book_Copies (branch_id) VALUES (book_copy.branch_id);
                END LOOP;		
            END LOOP;
        END;
		
	$$ LANGUAGE plpgsql;
	
	SELECT InsertBookCopies();

 	SELECT * FROM Book_Copies
ROLLBACK;

-- FULL

BEGIN;

	CREATE TEMPORARY TABLE Book_Copies_Temp AS (
		SELECT * FROM Book_Copies
	
	);
		
	DROP TABLE Book_Copies;
	
	CREATE TABLE Book_Copies (
		book_id SERIAL NOT NULL,
		acquisition_date DATE NOT NULL DEFAULT CURRENT_DATE,
		current_condition VARCHAR(255) NOT NULL DEFAULT 'good',
        branch_id INT NOT NULL,

		CONSTRAINT PK_Book_Copies PRIMARY KEY (book_id),
        CONSTRAINT FK_Book_Copies_Branch FOREIGN KEY (branch_id) REFERENCES Library_Branch(branch_id),
		CONSTRAINT Chk_Book_Copies_Current_Condition CHECK (current_condition IN ('fine', 'good', 'fair', 'poor'))
	
	);
	
	CREATE FUNCTION InsertBookCopies() RETURNS VOID AS $$ 
        DECLARE current_copy INT;
		DECLARE book_copy Book_Copies_Temp;
        BEGIN
            FOR book_copy IN SELECT * FROM Book_Copies_Temp LOOP     
				FOR current_copy IN 1..book_copy.no_of_copies LOOP
                	INSERT INTO Book_Copies (branch_id) VALUES (book_copy.branch_id);
                END LOOP;		
            END LOOP;
        END;
		
	$$ LANGUAGE plpgsql;
	
	SELECT InsertBookCopies();

 	SELECT * FROM Book_Copies

ROLLBACK;
