﻿CREATE PROCEDURE [dbo].[deleteSensor]
	@Id INT
AS
BEGIN
	SET NOCOUNT ON;
	DELETE FROM [Sensor]
	WHERE [id] = @Id;
END