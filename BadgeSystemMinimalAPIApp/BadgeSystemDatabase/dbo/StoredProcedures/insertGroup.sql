﻿CREATE PROCEDURE [dbo].[insertGroup]
	@Name NVARCHAR (MAX)
AS
BEGIN
	SET NOCOUNT ON;
	INSERT INTO [Group]([name])
	VALUES (@Name);
END
