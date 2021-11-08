
SELECT * FROM USER_TABLES;


----------------------------------BLOG 관련 TABLE-----------------------------------------

--BLOG 생성(여행일정 생성)할때 기본적으로 들어가는 테이블
--USER_ID와 BLOG SEQ에 PK를 주면 DAY별로 행이 추가될수없기때문에 PK는제외
CREATE TABLE BLOG_DETAIL(
	USER_ID VARCHAR2(50) NOT NULL,
	BLOG_SEQ NUMBER NOT NULL,
	BLOG_CREATE_DATE DATE NOT NULL,
	TITLE VARCHAR2(200) NOT NULL,
	CONTENT VARCHAR2(1000),
	AREA_NAME VARCHAR2(500) NOT NULL,
	TOUR_SEQ NUMBER NOT NULL,
	TOUR_DATE DATE NOT NULL, 
	PLACE VARCHAR2(4000) NOT NULL,
	IMG_PATH VARCHAR2(2000) NOT NULL,
	HEART_COUNT NUMBER DEFAULT 0 NOT NULL,
	COMMENT_COUNT NUMBER DEFAULT 0 NOT NULL,
	HITS_COUNT NUMBER DEFAULT 0 NOT NULL,
	CONSTRAINT FK_BLOG_DETAIL_USERID FOREIGN KEY(USER_ID) REFERENCES T_USER(USER_ID),
	CONSTRAINT PK_BLOG_DETAIL PRIMARY KEY(USER_ID, BLOG_SEQ, TOUR_SEQ)
);
delete FROM BLOG_DETAIL;


--------BLOG SELECT ONE--------
CREATE OR REPLACE VIEW V_BLOG_ONE
AS
	SELECT A.USER_ID, A.PENALTY, B.BLOG_SEQ, B.BLOG_CREATE_DATE, B.TITLE, B.CONTENT, B.IMG_PATH,
			B.AREA_NAME, B.TOUR_SEQ, B.TOUR_DATE, B.PLACE, B.HEART_COUNT, B.COMMENT_COUNT, B.HITS_COUNT 
	FROM T_USER A, BLOG_DETAIL B
	WHERE A.USER_ID = B.USER_ID
	AND A.ACTIVE = 'Y'
	ORDER BY A.USER_ID, B.BLOG_SEQ, B.TOUR_SEQ;
	
SELECT * FROM V_BLOG_ONE WHERE USER_ID = 'ILNAM' AND BLOG_SEQ = 1;
DROP VIEW V_BLOG_ONE;
------------------------------------------------------------------------
--------BLOG SELECT ALL--------
CREATE OR REPLACE VIEW V_BLOG_LIST
AS
	SELECT A.USER_ID, A.PENALTY, B.BLOG_SEQ, B.BLOG_CREATE_DATE, B.TITLE, B.CONTENT, B.AREA_NAME, 
			(SELECT MIN(TOUR_DATE)
			 FROM BLOG_DETAIL
			 WHERE USER_ID = A.USER_ID
			 AND BLOG_SEQ = B.BLOG_SEQ) AS MINDATE,
			(SELECT MAX(TOUR_DATE)
			 FROM BLOG_DETAIL
			 WHERE USER_ID = A.USER_ID
			 AND BLOG_SEQ = B.BLOG_SEQ) AS MAXDATE
			 ,B.IMG_PATH, B.HEART_COUNT, B.COMMENT_COUNT, B.HITS_COUNT 
	FROM T_USER A, BLOG_DETAIL B
	WHERE A.USER_ID = B.USER_ID
	AND A.ACTIVE = 'Y'
	AND B.TOUR_SEQ = 1
	ORDER BY B.HEART_COUNT DESC, B.HITS_COUNT DESC, B.BLOG_SEQ ASC;
	
SELECT * FROM V_BLOG_LIST;
DROP VIEW V_BLOG_LIST;
------------------------------------------------------------------------
-----------BLOG 게시판 (블로그 생성일 순으로 나오게)
CREATE OR REPLACE VIEW V_BLOG_LIST_DESC
AS
	SELECT A.USER_ID, A.PENALTY, B.BLOG_SEQ, B.BLOG_CREATE_DATE, B.TITLE, B.CONTENT, B.AREA_NAME, 
			(SELECT MIN(TOUR_DATE)
			 FROM BLOG_DETAIL
			 WHERE USER_ID = A.USER_ID
			 AND BLOG_SEQ = B.BLOG_SEQ) AS MINDATE,
			(SELECT MAX(TOUR_DATE)
			 FROM BLOG_DETAIL
			 WHERE USER_ID = A.USER_ID
			 AND BLOG_SEQ = B.BLOG_SEQ) AS MAXDATE
			 ,B.IMG_PATH, B.HEART_COUNT, B.COMMENT_COUNT, B.HITS_COUNT 
	FROM T_USER A, BLOG_DETAIL B
	WHERE A.USER_ID = B.USER_ID
	AND A.ACTIVE = 'Y'
	AND B.TOUR_SEQ = 1
	ORDER BY B.BLOG_CREATE_DATE DESC;
	
SELECT * FROM V_BLOG_LIST_DESC;

-------------------------------------------------------------------------
----블로그 selectone
CREATE OR REPLACE PROCEDURE BLOG_SELECTONE
(
	P_BLOGID IN VARCHAR2,
	P_BLOGSEQ IN NUMBER,
	p_cursor OUT SYS_REFCURSOR
)
IS
BEGIN 
	UPDATE BLOG_DETAIL 
	SET HITS_COUNT = HITS_COUNT + 1
	WHERE USER_ID = P_BLOGID
	AND BLOG_SEQ = P_BLOGSEQ;

	OPEN p_cursor FOR
	SELECT *
	FROM V_BLOG_ONE
	WHERE USER_ID = P_BLOGID
	AND BLOG_SEQ = P_BLOGSEQ;
	EXCEPTION
		 WHEN no_data_found THEN
        dbms_output.put_line('does not exits.');
    	ROLLBACK;
    COMMIT;
END;

--------------------------------------------------------------------------
-------MAX미리계산
CREATE OR REPLACE VIEW V_MAXBLOG
AS
SELECT MAX(BLOG_SEQ) MAXSEQ, USER_ID 
FROM V_BLOG_LIST
GROUP BY USER_ID;

SELECT * FROM V_MAXBLOG;
--------------------------------------------------------------------------
--------del blog
CREATE OR REPLACE PROCEDURE DELBLOG
(
	P_USERID IN VARCHAR2,
	P_BLOGSEQ IN NUMBER
)
IS 
BEGIN 
	DECLARE 
		X NUMBER;
	BEGIN 
		DELETE FROM BLOG_DETAIL
		WHERE USER_ID = P_USERID
		AND BLOG_SEQ = P_BLOGSEQ;
		
		DELETE FROM BLOG_HEART
		WHERE BLOG_ID = P_USERID
		AND BLOG_SEQ = P_BLOGSEQ;
	
		DELETE FROM BLOG_COMMENT
		WHERE BLOG_ID = P_USERID
		AND BLOG_SEQ = P_BLOGSEQ;
		
		EXCEPTION
        	WHEN no_data_found THEN
            	dbms_output.put_line('does not exits.'); RETURN;	
		COMMIT;
	END;
END;
/
--------------------------------------------------------------------------






-------------------------------------------------------------------------댓글
--PK : ID + BLOGSEQ + COMMENTSEQ
CREATE TABLE BLOG_COMMENT(
	BLOG_ID VARCHAR2(50) NOT NULL, --blogid 
	BLOG_SEQ NUMBER NOT NULL,	   --BLOGSEQ
	COMMENT_DATE DATE NOT NULL,    
	COMMENT_SEQ NUMBER NOT NULL,   --댓글번호
	COMMENT_GROUPNO NUMBER NOT NULL, --그룹번호 새로운글 작성시에만 부여
	COMMENT_GROUPSEQ NUMBER NOT NULL, --같은그룹안에서순서
	COMMENT_ID VARCHAR2(50) NOT NULL, 
	COMMENT_CONTENT VARCHAR2(500) NOT NULL,
	CONSTRAINT FK_BLOG_COMMENT_BLOGID FOREIGN KEY(BLOG_ID) REFERENCES T_USER(USER_ID),
	CONSTRAINT FK_BLOG_COMMENT_COMMENTID FOREIGN KEY(COMMENT_ID) REFERENCES T_USER(USER_ID),
	CONSTRAINT PK_BLOG_COMMENT PRIMARY KEY(BLOG_ID, BLOG_SEQ, COMMENT_SEQ)
);

--------------------------------------------------
CREATE OR REPLACE PROCEDURE BLOG_ADDCOMMENT
(
	P_BLOGID IN VARCHAR2,
	P_BLOGSEQ IN NUMBER,
	P_COMMENTID IN VARCHAR2,
	P_CONTENT IN VARCHAR2
)
IS
BEGIN 
	INSERT INTO BLOG_COMMENT 
	VALUES(P_BLOGID, P_BLOGSEQ, SYSDATE,
			(SELECT NVL(MAX(COMMENT_SEQ), 0) FROM BLOG_COMMENT WHERE BLOG_ID = P_BLOGID AND BLOG_SEQ = P_BLOGSEQ) + 1,
			(SELECT NVL(MAX(COMMENT_SEQ), 0) FROM BLOG_COMMENT WHERE BLOG_ID = P_BLOGID AND BLOG_SEQ = P_BLOGSEQ) + 1,
			1, P_COMMENTID, P_CONTENT);
		
		
	UPDATE BLOG_DETAIL 
	SET COMMENT_COUNT = COMMENT_COUNT + 1
	WHERE USER_ID = P_BLOGID
	AND BLOG_SEQ = P_BLOGSEQ;
	
	EXCEPTION
		WHEN DUP_VAL_ON_INDEX THEN ROLLBACK; RETURN;
		WHEN no_data_found THEN
        dbms_output.put_line('does not exits.');
    COMMIT;
END;
/
--------------------------------------------------

CREATE OR REPLACE PROCEDURE BLOG_DELCOMMENT
(
	P_BLOGID IN VARCHAR2,
	P_BLOGSEQ IN NUMBER,
	P_COMMENTSEQ IN NUMBER
)
IS
BEGIN 
	DELETE FROM BLOG_COMMENT
	WHERE BLOG_ID = P_BLOGID
	AND BLOG_SEQ = P_BLOGSEQ
	AND COMMENT_SEQ = P_COMMENTSEQ;
	IF SQL%ROWCOUNT = 0 THEN
	RETURN;
	END IF;

	UPDATE BLOG_DETAIL 
	SET COMMENT_COUNT = COMMENT_COUNT - 1
	WHERE USER_ID = P_BLOGID
	AND BLOG_SEQ = P_BLOGSEQ;

	EXCEPTION
		WHEN no_data_found THEN
        dbms_output.put_line('does not exits.');
    COMMIT;
END;
/
--------------------------------------------------

CREATE OR REPLACE PROCEDURE BLOG_DELCOMMENTALL
(
	P_BLOGID IN VARCHAR2,
	P_BLOGSEQ IN NUMBER,
	P_COMMENTSEQ IN NUMBER,
	P_GROUPNO IN NUMBER
)
IS
BEGIN 
	DELETE FROM BLOG_COMMENT
	WHERE BLOG_ID = P_BLOGID
	AND BLOG_SEQ = P_BLOGSEQ
	AND COMMENT_SEQ = P_COMMENTSEQ;
	IF SQL%ROWCOUNT = 0 THEN
	RETURN;
	END IF;

	UPDATE BLOG_DETAIL 
	SET COMMENT_COUNT = COMMENT_COUNT - ((SELECT COUNT(*) FROM BLOG_COMMENT B WHERE B.BLOG_ID = P_BLOGID AND B.BLOG_SEQ = P_BLOGSEQ AND B.COMMENT_GROUPNO = P_GROUPNO) + 1)
	WHERE USER_ID = P_BLOGID
	AND BLOG_SEQ = P_BLOGSEQ;

	DELETE FROM BLOG_COMMENT bc 
	WHERE bc.BLOG_ID = P_BLOGID
	AND bc.BLOG_SEQ = P_BLOGSEQ
	AND bc.COMMENT_GROUPNO = P_GROUPNO;

	EXCEPTION
		WHEN no_data_found THEN
        dbms_output.put_line('does not exits.');
    COMMIT;
END;
/
--------------------------------------------------

SELECT * FROM BLOG_COMMENT bc ;
--------------------------------------------------
CREATE OR REPLACE PROCEDURE BLOG_ADDANSWER
(
	P_BLOGID IN VARCHAR2,
	P_BLOGSEQ IN NUMBER,
	P_COMMENTID IN VARCHAR2,
	P_ANSWER IN VARCHAR2,
	P_GROUPNO IN NUMBER
)
IS
BEGIN 
	INSERT INTO BLOG_COMMENT 
	VALUES(P_BLOGID, P_BLOGSEQ, SYSDATE,
			(SELECT NVL(MAX(COMMENT_SEQ), 0) FROM BLOG_COMMENT WHERE BLOG_ID = P_BLOGID AND BLOG_SEQ = P_BLOGSEQ) + 1,
			P_GROUPNO,
			(SELECT MAX(COMMENT_GROUPSEQ) FROM BLOG_COMMENT WHERE BLOG_ID = P_BLOGID AND BLOG_SEQ = P_BLOGSEQ) + 1,
			P_COMMENTID, 
			P_ANSWER);
		
		
	UPDATE BLOG_DETAIL 
	SET COMMENT_COUNT = COMMENT_COUNT + 1
	WHERE USER_ID = P_BLOGID
	AND BLOG_SEQ = P_BLOGSEQ;
	
	EXCEPTION
		WHEN DUP_VAL_ON_INDEX THEN ROLLBACK; RETURN;
		WHEN no_data_found THEN
        dbms_output.put_line('does not exits.');
    COMMIT;
END;
/
--------------------------------------------------
---------------------------COMMENT----------------









--블로그주인이 블로그를 삭제하면 블로그찜테이블에서도 해당 블로그가 포함된 행 자동삭제
------------------------------------------------------------------------------블로그찜
--pk (userid, blogid, blogseq)
CREATE TABLE BLOG_HEART(
	REG_DATE DATE NOT NULL,
	USER_ID VARCHAR2(50) NOT NULL,
	BLOG_ID VARCHAR2(50) NOT NULL,
	BLOG_SEQ NUMBER NOT NULL,
	BLOG_TITLE VARCHAR2(1000) NOT NULL,
	CONSTRAINT FK_BLOG_HEART_USERID FOREIGN KEY(USER_ID) REFERENCES T_USER(USER_ID),
	CONSTRAINT FK_BLOG_HEART_BLOGID FOREIGN KEY(BLOG_ID) REFERENCES T_USER(USER_ID),
	CONSTRAINT PK_BLOG_HEART PRIMARY KEY(USER_ID, BLOG_ID, BLOG_SEQ)
);
ALTER TABLE BLOG_HEART ADD FOREIGN KEY(BLOG_ID) REFERENCES T_USER(USER_ID);

SELECT * FROM BLOG_HEART;
DROP TABLE BLOG_HEART;


--블로그찜추가------------------------------------------------
CREATE OR REPLACE PROCEDURE ADD_BLOGHEART
(
	P_USERID IN VARCHAR2,
	P_BLOGID IN VARCHAR2,
	P_BLOGSEQ IN NUMBER,
	P_BLOGTITLE IN VARCHAR2
)
IS
BEGIN 
	INSERT INTO BLOG_HEART
	VALUES(SYSDATE, P_USERID, P_BLOGID, P_BLOGSEQ, P_BLOGTITLE);

	EXCEPTION
		WHEN DUP_VAL_ON_INDEX THEN 
		RAISE NO_DATA_FOUND; RETURN;
    COMMIT;
END;
/

--블로그찜삭제------------------------------------------------
CREATE OR REPLACE PROCEDURE RM_BLOGHEART
(
	P_USERID IN VARCHAR2,
	P_BLOGID IN VARCHAR2,
	P_BLOGSEQ IN NUMBER
)
IS
BEGIN 
	DELETE FROM BLOG_HEART
	WHERE USER_ID = P_USERID
	AND BLOG_ID =P_BLOGID
	AND BLOG_SEQ =P_BLOGSEQ;
	IF SQL%ROWCOUNT = 0 THEN
    	RAISE NO_DATA_FOUND; RETURN;
	END IF;	

    COMMIT;
END;
/

--초기 페이지오픈시 찜여부확인용------------------------------------------------
CREATE OR REPLACE PROCEDURE CONFIRM_BLOGHEART
(
	P_USERID IN VARCHAR2,
	P_BLOGID IN VARCHAR2,
	P_BLOGSEQ IN NUMBER,
	p_cursor OUT SYS_REFCURSOR
)
IS 
BEGIN 
	OPEN p_cursor FOR 
	SELECT * FROM BLOG_HEART WHERE USER_ID = P_USERID AND BLOG_ID = P_BLOGID AND BLOG_SEQ = P_BLOGSEQ;
	EXCEPTION
        WHEN no_data_found THEN
            dbms_output.put_line('does not exits.');
END;
/

--블로그 뷰 (찜대상 블로그 주인이 ACTIVE Y인 블로그만)------------------------------------------------
CREATE OR REPLACE VIEW V_BLOG_HEARTLIST
AS
	SELECT A.*, B.NICKNAME 
	FROM BLOG_HEART A, T_USER B
	WHERE A.BLOG_ID = B.USER_ID 
	AND B.ACTIVE = 'Y';
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------

















--------------------------------------------------------------------------------장소찜
-----------------------장소찜테이블
CREATE TABLE PLACE_HEART(
	USER_ID VARCHAR2(50) NOT NULL,
	PLACE_ID VARCHAR2(300) NOT NULL,
	THUMBNAIL VARCHAR2(500) NOT NULL,
	PLACE_NAME VARCHAR2(300) NOT NULL,
	LATITUDE VARCHAR2(50) NOT NULL,
	LONGITUDE VARCHAR2(50) NOT NULL,
	PLACE_ADDRESS VARCHAR2(500) NOT NULL,
	NATION VARCHAR2(50) NOT NULL,
	CITY VARCHAR2(50) NULL,
	CONSTRAINT FK_PLACE_HEART_USERID FOREIGN KEY(USER_ID) REFERENCES T_USER(USER_ID),
	CONSTRAINT PK_PLACE_HEART PRIMARY KEY(USER_ID, PLACE_ID)
);
SELECT * FROM PLACE_HEART;
SELECT * FROM T_USER;


--------------------------------------------------------------------------------
--찜수 계산 VIEW
CREATE OR REPLACE VIEW COUNT_PLACE_HEART
AS
	SELECT COUNT(PLACE_ID) CNT, PLACE_ID PID
	FROM PLACE_HEART
	GROUP BY PLACE_ID ;


SELECT * FROM COUNT_PLACE_HEART;
--------------------------------------------------------------------------------
-----유저장소찜 추가 프로시저
CREATE OR REPLACE PROCEDURE ADDHEART
(
	P_USERID IN VARCHAR2,
	P_PLACEID IN VARCHAR2,
	P_THUMBNAIL IN VARCHAR2,
	P_PLACENAME IN VARCHAR2,
	P_LATITUDE IN VARCHAR2,
	P_LONGTITUDE IN VARCHAR2,
	P_ADDRESS IN VARCHAR2,
	P_NATION IN VARCHAR2,
	P_CITY IN VARCHAR2,
	p_cursor OUT SYS_REFCURSOR
)
IS
BEGIN 
	INSERT INTO PLACE_HEART 
	VALUES(P_USERID, P_PLACEID, P_THUMBNAIL, P_PLACENAME, P_LATITUDE, P_LONGTITUDE, P_ADDRESS, P_NATION, P_CITY);

	OPEN p_cursor FOR 
	SELECT CNT FROM COUNT_PLACE_HEART WHERE PID = P_PLACEID;
	EXCEPTION
		WHEN DUP_VAL_ON_INDEX THEN RETURN;
        WHEN no_data_found THEN
        dbms_output.put_line('does not exits.');
    COMMIT;
END;
/
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-----유저장소찜 삭제 프로시저
CREATE OR REPLACE PROCEDURE RMHEART
(
	P_USERID IN VARCHAR2,
	P_PLACEID IN VARCHAR2,
	p_cursor OUT SYS_REFCURSOR
)
IS 
BEGIN 
	DELETE FROM PLACE_HEART WHERE USER_ID = P_USERID AND PLACE_ID = P_PLACEID;
	IF SQL%ROWCOUNT = 0 THEN
    	RETURN;
	END IF;	

	OPEN p_cursor FOR
	SELECT COUNT(PLACE_ID) FROM PLACE_HEART WHERE PLACE_ID =P_PLACEID;
	EXCEPTION
        WHEN no_data_found THEN
            dbms_output.put_line('does not exits.');
    COMMIT;
END;
/

--------------------------------------------------------------------------------
-----초반에 찜여부 확인
CREATE OR REPLACE PROCEDURE CONFIRM_HEART
(
	P_USERID IN VARCHAR2,
	P_PLACEID IN VARCHAR2,
	p_cursor OUT SYS_REFCURSOR
)
IS 
BEGIN 
	OPEN p_cursor FOR 
	SELECT PLACE_ID FROM PLACE_HEART WHERE PLACE_ID = P_PLACEID AND USER_ID = P_USERID;
	EXCEPTION
        WHEN no_data_found THEN
            dbms_output.put_line('does not exits.');
END;
/

--------------------------------------------------------------------------------
-----초반에 heart count 가져오기
CREATE OR REPLACE PROCEDURE GETHEARTCOUNT
(
	P_PLACEID IN VARCHAR2,
	p_cursor OUT SYS_REFCURSOR
)
IS
BEGIN 
	OPEN p_cursor FOR 
	SELECT COUNT(PLACE_ID) FROM PLACE_HEART WHERE PLACE_ID = P_PLACEID;
	EXCEPTION
        WHEN no_data_found THEN
            dbms_output.put_line('does not exits.');
END;
/

-----heart count 프로시저 커서 테스트
DECLARE
v_cursor SYS_REFCURSOR;
emp_rec NUMBER;
BEGIN
GETHEARTCOUNT('ChIJgf4OJaelfDURmDvA_sHyPUM', v_cursor);
FETCH v_cursor INTO emp_rec;
DBMS_OUTPUT.PUT_LINE(emp_rec);
END;
--------------------------------------------------------------------------------









SELECT * FROM TEST;

SELECT * FROM TAB;
SELECT * FROM BLOG_NEWSBOARD;

SELECT * FROM V_BLOG_LIST_DESC;
SELECT * FROM V_BLOG_LIST; 

