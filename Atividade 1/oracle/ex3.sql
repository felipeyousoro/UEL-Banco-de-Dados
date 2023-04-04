CREATE OR REPLACE FUNCTION Levenshtein(str1 VARCHAR, str2 VARCHAR)
    RETURN INT
    IS
        TYPE Matrix IS TABLE OF INTEGER INDEX BY PLS_INTEGER;
        TYPE Matrix2D IS TABLE OF Matrix INDEX BY PLS_INTEGER;
        len1 INT;
        len2 INT;
        d Matrix2D;
        i INT;
        j INT;
    BEGIN
        len1 := LENGTH(str1);
        len2 := LENGTH(str2);

        IF len1 = 0 THEN
            RETURN len2;
        ELSIF len2 = 0 THEN
            RETURN len1;
        END IF;

        FOR i IN 0..len1 LOOP
            d(i)(0) := i;
        END LOOP;

        FOR j IN 0..len2 LOOP
            d(0)(j) := j;
        END LOOP;

        FOR i IN 1..len1 LOOP
            FOR j IN 1..len2 LOOP
                IF SUBSTR(str1, i, 1) = SUBSTR(str2, j, 1) THEN
                    d(i)(j) := d(i-1)(j-1);
                ELSE
                    d(i)(j) := LEAST(d(i-1)(j), d(i)(j-1), d(i-1)(j-1)) + 1;
                END IF;
            END LOOP;
        END LOOP;

        RETURN d(len1)(len2);

    END;

CREATE OR REPLACE FUNCTION Get_Shortened_Middle_Name(p_name VARCHAR)
    RETURN VARCHAR
    IS
    shortened_middle_name VARCHAR(1);
    BEGIN
        SELECT SUBSTR(REGEXP_SUBSTR(p_name, '\S+', 1, 2), 1, 1) INTO shortened_middle_name FROM DUAL;
        RETURN shortened_middle_name;
    END;

CREATE OR REPLACE FUNCTION Get_Shortened_Name(p_name VARCHAR)
    RETURN VARCHAR
    IS
    v_first_name VARCHAR(50);
    v_middle_name VARCHAR(50);
    v_surname VARCHAR(50);
    BEGIN
        SELECT
            REGEXP_SUBSTR(p_name, '\S+', 1, 1),
            Get_Shortened_Middle_Name(p_name),
            REGEXP_SUBSTR(p_name, '\S+', 1, 3)
        INTO v_first_name, v_middle_name, v_surname FROM DUAL;

        RETURN v_first_name || ' ' || v_middle_name || '. ' || v_surname;
    END;


--PAREI AQUI!!!!

CREATE TABLE Felipe.Book_Authors_Log (
    book_id NUMBER NOT NULL,
    new_author_name VARCHAR2(255) NOT NULL,
    old_author_name VARCHAR2(255) NOT NULL,
    update_timestamp TIMESTAMP DEFAULT SYSDATE NOT NULL
);

CREATE OR REPLACE FUNCTION Log_Author_Update(p_old_book_id NUMBER, p_old_author_name VARCHAR2, p_new_book_id NUMBER, p_new_author_name VARCHAR2)
    RETURN NUMBER
    AS
    BEGIN
        INSERT INTO Felipe.Book_Authors_Log (book_id, new_author_name, old_author_name)
            VALUES (p_new_book_id, p_new_author_name, p_old_author_name);
        RETURN p_new_book_id;
    END;


CREATE OR REPLACE TRIGGER Log_Author_Update_Trigger
    AFTER UPDATE ON Felipe.Book_Authors
    FOR EACH ROW
    WHEN (OLD.author_name <> NEW.author_name)
        DECLARE
            v_new_book_id NUMBER;
        BEGIN
            v_new_book_id := Log_Author_Update(:OLD.book_id, :OLD.author_name, :NEW.book_id, :NEW.author_name);
        END;

CREATE OR REPLACE PROCEDURE Felipe.Detect_And_Reconcile_Authors AS
    v_record1_book_author_name VARCHAR2(150);
    v_author_name VARCHAR2(150);
    v_count NUMBER;
    v_count_sum NUMBER;
    CURSOR v_cursor1 IS
        SELECT author_name FROM Felipe.Book_Authors FOR UPDATE;
    BEGIN
        OPEN v_cursor1;
        LOOP
            FETCH v_cursor1 INTO v_record1_book_author_name;
            EXIT WHEN v_cursor1%NOTFOUND;

            v_count := NULL;
            v_author_name := NULL;

            SELECT author_name, COUNT(*) AS author_count
                INTO v_author_name, v_count
                FROM Felipe.Book_Authors

                -- Descobri que tinha esquecido de colocar o AND no pgsql, corrigi aqui.
                WHERE (Levenshtein(author_name, v_record1_book_author_name) < 3
                    OR Levenshtein(Get_Shortened_Name(author_name), Get_Shortened_Name(v_record1_book_author_name)) < 3)
                    AND Get_Shortened_Middle_Name(author_name) = Get_Shortened_Middle_Name(v_record1_book_author_name)
                GROUP BY author_name
                ORDER BY author_count DESC
                FETCH FIRST 1 ROW ONLY;

            IF v_count IS NOT NULL AND v_author_name IS NOT NULL THEN

                SELECT SUM(v_count) INTO v_count_sum FROM DUAL;

                    UPDATE Felipe.Book_Authors
                    SET author_name = v_author_name
                    WHERE (Levenshtein(author_name, v_author_name) < 3
                        OR Levenshtein(Get_Shortened_Name(author_name), Get_Shortened_Name(v_record1_book_author_name)) < 3)
                        AND Get_Shortened_Middle_Name(author_name) = Get_Shortened_Middle_Name(v_record1_book_author_name);

            END IF;

        END LOOP;
        CLOSE v_cursor1;
    END;

BEGIN
    Felipe.Detect_And_Reconcile_Authors;
END;

DROP PROCEDURE Felipe.Detect_And_Reconcile_Authors;

-- SELECT * FROM Felipe.Book_Authors;
-- SELECT * FROM Felipe.Book_Authors_Log;


