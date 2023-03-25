CREATE MATERIALIZED VIEW Felipe.month_borrowers (
    card_no,
    name,
    address,
    phone,
    loan_length,
    book_title,
    branch_name ) AS
    SELECT b.card_no,
            b.name,
            b.address,
            b.phone,
            (bl.due_date - bl.date_out) AS loan_length,
            bo.title                    AS book_title,
            lb.branch_name
        FROM Felipe.Borrower b
        JOIN Felipe.Book_Loans bl ON b.card_no = bl.card_no
        JOIN Felipe.Book bo ON bl.book_id = bo.book_id
        JOIN Felipe.Library_Branch lb ON bl.branch_id = lb.branch_id
        WHERE (bl.due_date - bl.date_out) > 30;
