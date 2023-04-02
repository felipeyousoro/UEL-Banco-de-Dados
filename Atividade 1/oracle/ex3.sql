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

CREATE TABLE Book_Loans.Book_Authors_Log (
    book_id INT NOT NULL,
    new_author_name VARCHAR(255) NOT NULL,
    old_author_name VARCHAR(255) NOT NULL,
    update_timestamp TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE FUNCTION Book_Loans.Log_Author_Update() RETURNS TRIGGER AS $$
    BEGIN
        INSERT INTO Book_Loans.Book_Authors_Log (book_id, new_author_name, old_author_name)
            VALUES (NEW.book_id, NEW.author_name, OLD.author_name);
        RETURN NEW;
    END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER Log_Author_Update
    AFTER UPDATE ON Book_Loans.Book_Authors
    FOR EACH ROW
    WHEN (OLD.author_name <> NEW.author_name)
    EXECUTE PROCEDURE Book_Loans.Log_Author_Update();


CREATE PROCEDURE Book_Loans.Detect_And_Reconcile_Authors() LANGUAGE plpgsql AS $$
    DECLARE
        _record1 RECORD;
        _record2 RECORD;
        _author_name VARCHAR;
        _count INT;
        _count_sum INT;
        _cursor1 CURSOR FOR SELECT author_name FROM Book_Loans.Book_Authors FOR UPDATE;
    BEGIN
        OPEN _cursor1;
        LOOP
            FETCH _cursor1 INTO _record1;

            EXIT WHEN NOT FOUND;
            -- Definitivamente otimizavel, mas a logica e a seguinte

            -- Contagem do nome mais comum caso siga os seguintes requisitos:

                -- 1. As diferenças dos nomes originais sao ate 2 (ha possibilidade de algum nome aqui
                    -- ja estar reduzido)
                -- 2. As diferenças dos nomes reduzidos sao ate 2

                -- 3. Satisfeitas alguma das condiçoes
                    -- o nome do meio reduzido DEVE ser igual, para que nao sejam casados nomes
                    -- cuja unica diferenca seja o nome do meio

            -- Atualiza todos os nomes que satisfazem os requisitos anteriores
            -- com o primeiro da contagem (por isso o limit 1)
                SELECT author_name, COUNT(*) AS author_count
                    INTO _author_name, _count
                    FROM Book_Loans.Book_Authors
                    WHERE Levenshtein(author_name, _record1.author_name) < 3 OR
                        Levenshtein(Book_Loans.Get_Shortened_Name(author_name), Book_Loans.Get_Shortened_Name(_record1.author_name)) < 3 OR
                        Book_Loans.Get_Shortened_Middle_Name(author_name) = Book_Loans.Get_Shortened_Middle_Name(_record1.author_name)
                    GROUP BY author_name
                    ORDER BY author_count DESC
                    LIMIT 1;

                    SELECT SUM(_count) INTO _count_sum;

                UPDATE Book_Loans.Book_Authors
                    SET author_name = _author_name
                    WHERE Levenshtein(author_name, _author_name) < 3 OR
                        Levenshtein(Book_Loans.Get_Shortened_Name(author_name), Book_Loans.Get_Shortened_Name(_record1.author_name)) < 3 OR
                        Book_Loans.Get_Shortened_Middle_Name(author_name) = Book_Loans.Get_Shortened_Middle_Name(_record1.author_name);


        END LOOP;
        CLOSE _cursor1;
    END;
$$;

CALL Book_Loans.Detect_And_Reconcile_Authors();

-- Eu nao sei se o procedimento foi feito para ser chamado uma vez ou varias vezes
-- entao eu decidi deletar
DROP PROCEDURE Book_Loans.Detect_And_Reconcile_Authors;

-- SELECT * FROM Book_Loans.Book_Authors;
-- SELECT * FROM Book_Loans.Book_Authors_Log;



