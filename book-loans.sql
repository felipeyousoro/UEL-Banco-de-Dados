CREATE TABLE Publisher (
  publisher_name VARCHAR(255) NOT NULL,
  _address VARCHAR(255) NOT NULL,
  phone VARCHAR(255) NOT NULL,

  CONSTRAINT PK_Publisher PRIMARY KEY (publisher_name)
);

CREATE TABLE Book (
  book_id INT NOT NULL,
  
  title VARCHAR(255) NOT NULL,
  publisher_name VARCHAR(255) NOT NULL,

  CONSTRAINT PK_Book PRIMARY KEY (book_id),
    CONSTRAINT FK_Book_Publisher FOREIGN KEY (publisher_name) REFERENCES Publisher(publisher_name)
);

CREATE TABLE Library_Branch (
  branch_id INT NOT NULL,
  branch_name VARCHAR(255) NOT NULL,
  _address VARCHAR(255) NOT NULL,

  CONSTRAINT PK_Library_Branch PRIMARY KEY (branch_id)
);

CREATE TABLE Borrower (
  card_no INT NOT NULL,
  name VARCHAR(255) NOT NULL,
  _address VARCHAR(255) NOT NULL,
    phone VARCHAR(255) NOT NULL,

  CONSTRAINT PK_Borrower PRIMARY KEY (card_no)
);

CREATE TABLE Book_Authors (
    book_id INT NOT NULL,
    author_name VARCHAR(255) NOT NULL,

    CONSTRAINT PK_Book_Authors PRIMARY KEY (book_id, author_name),
    CONSTRAINT FK_Book_Authors_Book FOREIGN KEY (book_id) REFERENCES Book(book_id) 
);

CREATE TABLE Book_Copies (
    book_id INT NOT NULL,
    branch_id INT NOT NULL,
    no_of_copies INT NOT NULL,

    CONSTRAINT PK_Book_Copies PRIMARY KEY (book_id, branch_id),
    CONSTRAINT FK_Book_Copies_Book FOREIGN KEY (book_id) REFERENCES Book(book_id),
    CONSTRAINT FK_Book_Copies_Branch FOREIGN KEY (branch_id) REFERENCES Library_Branch(branch_id)
);

CREATE TABLE Book_Loans (
    book_id INT NOT NULL,
    branch_id INT NOT NULL,
    card_no INT NOT NULL,
    date_out DATE NOT NULL,
    due_date DATE NOT NULL,

    CONSTRAINT PK_Book_Loans PRIMARY KEY (book_id, branch_id, card_no),
    CONSTRAINT FK_Book_Loans_Book FOREIGN KEY (book_id) REFERENCES Book(book_id),
    CONSTRAINT FK_Book_Loans_Branch FOREIGN KEY (branch_id) REFERENCES Library_Branch(branch_id),
    CONSTRAINT FK_Book_Loans_Borrower FOREIGN KEY (card_no) REFERENCES Borrower(card_no)
);

INSERT INTO Publisher VALUES ('Penguin', 'London', '123-456-7890');
INSERT INTO Publisher VALUES ('HarperCollins', 'New York', '123-456-7890');
INSERT INTO Publisher VALUES ('Macmillan', 'London', '123-456-7890');

INSERT INTO Book VALUES (1, 'The Great Gatsby', 'Penguin');
INSERT INTO Book VALUES (2, 'The Catcher in the Rye', 'Penguin');
INSERT INTO Book VALUES (3, 'The Grapes of Wrath', 'Penguin');

INSERT INTO Library_Branch VALUES (1, 'Main', '123 Main St');
INSERT INTO Library_Branch VALUES (2, 'Branch', '456 Branch St');

INSERT INTO Borrower VALUES (1, 'John Smith', '123 Main St', '123-456-7890');
INSERT INTO Borrower VALUES (2, 'Jane Doe', '456 Branch St', '123-456-7890');

INSERT INTO Book_Authors VALUES (1, 'F. Scott Fitzgerald');
INSERT INTO Book_Authors VALUES (2, 'J. D. Salinger');
INSERT INTO Book_Authors VALUES (3, 'John Steinbeck');

INSERT INTO Book_Copies VALUES (1, 1, 2);
INSERT INTO Book_Copies VALUES (1, 2, 1);
INSERT INTO Book_Copies VALUES (2, 1, 11);
INSERT INTO Book_Copies VALUES (2, 2, 2);
INSERT INTO Book_Copies VALUES (3, 1, 1);
INSERT INTO Book_Copies VALUES (3, 2, 1);

INSERT INTO Book_Loans VALUES (1, 1, 1, '2017-01-01', '2017-01-08');
INSERT INTO Book_Loans VALUES (2, 1, 1, '2017-01-01', '2017-01-08');
INSERT INTO Book_Loans VALUES (3, 1, 1, '2017-01-01', '2017-02-08');
INSERT INTO Book_Loans VALUES (1, 2, 2, '2017-01-01', '2017-01-08');
INSERT INTO Book_Loans VALUES (2, 2, 2, '2017-01-01', '2017-03-08');
INSERT INTO Book_Loans VALUES (3, 2, 2, '2017-01-01', '2017-02-08');

--- exercicio 2

2. Assume that after having deployed the database and loaded it with data, the library manager
decided to store book copies individually. From now on, the database should store an id, the
acquisition date, and the current conditions (fine, good, fair, or poor) for each copy. Book loans
should refer to a specific book copy. The attribute no_of_copies should no longer be stored in the
database. However, existing applications should "see" the database as if the schema had not been
updated for backward compatibility.

Implement the commands to perform the necessary change to the database schema.

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


 
