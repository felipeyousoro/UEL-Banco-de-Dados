-- sem criatividade para nome do schema, então usei o nome do projeto
CREATE SCHEMA Book_Loans;

CREATE TABLE Book_Loans.Publisher (
    publisher_name VARCHAR(255) NOT NULL,
    _address VARCHAR(255) NOT NULL,
    phone VARCHAR(255) NOT NULL,

    CONSTRAINT PK_Publisher PRIMARY KEY (publisher_name)
);

CREATE TABLE Book_Loans.Book (
    book_id INT NOT NULL,

    title VARCHAR(255) NOT NULL,
    publisher_name VARCHAR(255) NOT NULL,

    CONSTRAINT PK_Book PRIMARY KEY (book_id),
    CONSTRAINT FK_Book_Publisher FOREIGN KEY (publisher_name) REFERENCES Book_Loans.Publisher(publisher_name)
);

CREATE TABLE Book_Loans.Library_Branch (
    branch_id INT NOT NULL,
    branch_name VARCHAR(255) NOT NULL,
    _address VARCHAR(255) NOT NULL,

    CONSTRAINT PK_Library_Branch PRIMARY KEY (branch_id)
);

CREATE TABLE Book_Loans.Borrower (
    card_no INT NOT NULL,
    name VARCHAR(255) NOT NULL,
    _address VARCHAR(255) NOT NULL,
    phone VARCHAR(255) NOT NULL,

    CONSTRAINT PK_Borrower PRIMARY KEY (card_no)
);

CREATE TABLE Book_Loans.Book_Authors (
    book_id INT NOT NULL,
    author_name VARCHAR(255) NOT NULL,

    CONSTRAINT PK_Book_Authors PRIMARY KEY (book_id, author_name),
    CONSTRAINT FK_Book_Authors_Book FOREIGN KEY (book_id) REFERENCES Book_Loans.Book(book_id) 
);

CREATE TABLE Book_Loans.Book_Copies (
    book_id INT NOT NULL,
    branch_id INT NOT NULL,
    no_of_copies INT NOT NULL,

    CONSTRAINT PK_Book_Copies PRIMARY KEY (book_id, branch_id),
    CONSTRAINT FK_Book_Copies_Book FOREIGN KEY (book_id) REFERENCES Book_Loans.Book(book_id),
    CONSTRAINT FK_Book_Copies_Branch FOREIGN KEY (branch_id) REFERENCES Book_Loans.Library_Branch(branch_id)
);

CREATE TABLE Book_Loans.Book_Loans (
    book_id INT NOT NULL,
    branch_id INT NOT NULL,
    card_no INT NOT NULL,
    date_out DATE NOT NULL,
    due_date DATE NOT NULL,

    CONSTRAINT PK_Book_Loans PRIMARY KEY (book_id, branch_id, card_no),
    CONSTRAINT FK_Book_Loans_Book FOREIGN KEY (book_id) REFERENCES Book_Loans.Book(book_id),
    CONSTRAINT FK_Book_Loans_Branch FOREIGN KEY (branch_id) REFERENCES Book_Loans.Library_Branch(branch_id),
    CONSTRAINT FK_Book_Loans_Borrower FOREIGN KEY (card_no) REFERENCES Book_Loans.Borrower(card_no),
    CONSTRAINT CHK_Book_Loans_Due_Date CHECK (due_date > date_out)

);

INSERT INTO Book_Loans.Publisher VALUES ('Penguin', 'London', '123-456-7890');
INSERT INTO Book_Loans.Publisher VALUES ('HarperCollins', 'New York', '123-456-7890');
INSERT INTO Book_Loans.Publisher VALUES ('Macmillan', 'London', '123-456-7890');

INSERT INTO Book_Loans.Book VALUES (1, 'The Great Gatsby', 'Penguin');
INSERT INTO Book_Loans.Book VALUES (2, 'The Catcher in the Rye', 'Penguin');
INSERT INTO Book_Loans.Book VALUES (3, 'The Grapes of Wrath', 'Penguin');
INSERT INTO Book_Loans.Book VALUES (4, 'Quatro', 'Penguin');
INSERT INTO Book_Loans.Book VALUES (5, 'Cinco', 'Penguin');
INSERT INTO Book_Loans.Book VALUES (6, 'Seis', 'Penguin');
INSERT INTO Book_Loans.Book VALUES (7, 'Sete', 'Penguin');
INSERT INTO Book_Loans.Book VALUES (8, 'Sete', 'Penguin');
INSERT INTO Book_Loans.Book VALUES (9, 'Sete', 'Penguin');
INSERT INTO Book_Loans.Book VALUES (10, 'Sete', 'Penguin');
INSERT INTO Book_Loans.Book VALUES (11, 'Sete', 'Penguin');
INSERT INTO Book_Loans.Book VALUES (12, 'Sete', 'Penguin');
INSERT INTO Book_Loans.Book VALUES (13, 'Sete', 'Penguin');
INSERT INTO Book_Loans.Book VALUES (14, 'Sete', 'Penguin');
INSERT INTO Book_Loans.Book VALUES (15, 'Sete', 'Penguin');
INSERT INTO Book_Loans.Book VALUES (16, 'Sete', 'Penguin');
INSERT INTO Book_Loans.Book VALUES (17, 'Sete', 'Penguin');
INSERT INTO Book_Loans.Book VALUES (18, 'Sete', 'Penguin');

INSERT INTO Book_Loans.Library_Branch VALUES (1, 'Main', '123 Main St');
INSERT INTO Book_Loans.Library_Branch VALUES (2, 'Branch', '456 Branch St');

INSERT INTO Book_Loans.Borrower VALUES (1, 'John Smith', '123 Main St', '123-456-7890');
INSERT INTO Book_Loans.Borrower VALUES (2, 'Jane Doe', '456 Branch St', '123-456-7890');
INSERT INTO Book_Loans.Borrower VALUES (3, 'John Doe', '789 Branch St', '123-456-7890');
INSERT INTO Book_Loans.Borrower VALUES (4, 'Jane Smith', '123 Branch St', '123-456-7890');
INSERT INTO Book_Loans.Borrower VALUES (5, 'John Smith', '456 Main St', '123-456-7890');

INSERT INTO Book_Loans.Book_Authors VALUES (1, 'F. Scott Fitzgerald');
INSERT INTO Book_Loans.Book_Authors VALUES (2, 'J. D. Salinger');
INSERT INTO Book_Loans.Book_Authors VALUES(4, 'John Joseph Powell');
INSERT INTO Book_Loans.Book_Authors VALUES(5, 'John J. Powell');
INSERT INTO Book_Loans.Book_Authors VALUES(6, 'John Joseph Poweell');
INSERT INTO Book_Loans.Book_Authors VALUES(7, 'John Joseph Powell');
INSERT INTO Book_Loans.Book_Authors VALUES(8, 'John James Powell');
INSERT INTO Book_Loans.Book_Authors VALUES(9, 'John J. Powell');
INSERT INTO Book_Loans.Book_Authors VALUES(10, 'John James Pwoell');
INSERT INTO Book_Loans.Book_Authors VALUES(11, 'John James Poweell');
INSERT INTO Book_Loans.Book_Authors VALUES(12, 'John A. Poweell');

INSERT INTO Book_Loans.Book_Copies VALUES (1, 1, 2);
INSERT INTO Book_Loans.Book_Copies VALUES (1, 2, 1);
INSERT INTO Book_Loans.Book_Copies VALUES (2, 1, 11);
INSERT INTO Book_Loans.Book_Copies VALUES (2, 2, 2);
INSERT INTO Book_Loans.Book_Copies VALUES (3, 1, 1);
INSERT INTO Book_Loans.Book_Copies VALUES (3, 2, 1);

INSERT INTO Book_Loans.Book_Loans VALUES (1, 1, 1, '2017-01-01', '2017-01-08');
INSERT INTO Book_Loans.Book_Loans VALUES (1, 1, 2, '2017-01-02', '2017-01-08');
INSERT INTO Book_Loans.Book_Loans VALUES (1, 1, 3, '2017-01-09', '2017-01-11');
INSERT INTO Book_Loans.Book_Loans VALUES (1, 1, 4, '2017-01-09', '2017-01-10');
INSERT INTO Book_Loans.Book_Loans VALUES (1, 1, 5, '2017-01-11', '2017-01-12');
INSERT INTO Book_Loans.Book_Loans VALUES (2, 1, 1, '2017-01-01', '2017-01-08');
INSERT INTO Book_Loans.Book_Loans VALUES (3, 1, 1, '2017-01-01', '2017-02-08');
INSERT INTO Book_Loans.Book_Loans VALUES (1, 2, 2, '2017-01-01', '2017-01-08');
INSERT INTO Book_Loans.Book_Loans VALUES (2, 2, 2, '2017-01-01', '2017-03-08');
INSERT INTO Book_Loans.Book_Loans VALUES (3, 2, 2, '2017-01-01', '2017-02-08');
