<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>

<% request.setCharacterEncoding("UTF-8"); %>
<% response.setContentType("text/html; charset=UTF-8"); %>  

 <%@ page import="com.mvc.dto.BlognewsboardDto" %> 
 <%@ page import="com.mvc.dao.BlogDao" %>
 
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>Insert title here</title>
</head>
<body>
<%
	String writer = request.getParameter("myname");
	String title = request.getParameter("mytitle");
	String content = request.getParameter("mycontent");
	
	BlognewsboardDto dto = new BlognewsboardDto(writer,title,content);
	
	BlogDao dao = new BlogDao();
	int res = dao.insert(dto);
	
	if(res>0){
%>		
	<script type="text/javascript">
		alert("게시글 등록이 완료되었습니다.");
		location.href="newslist.jsp";
	</script>
<%
	}else{
%>
	<script type="text/javascript">
		alert("글 등록 실패");
		location.href="insert.jsp";
	</script>
<%		
	}
%>
</body>
</html>