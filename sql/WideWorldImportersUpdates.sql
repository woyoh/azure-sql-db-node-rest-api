/*
	Create schema
*/
IF SCHEMA_ID('web') IS NULL BEGIN	
	EXECUTE('CREATE SCHEMA [web]');
END
GO

/*
	Create user to be used in the sample API solution
*/
IF USER_ID('NodeFuncApp') IS NULL BEGIN	
	CREATE USER [NodeFuncApp] WITH PASSWORD = 'aN0ThErREALLY#$%TRONGpa44w0rd!';	
END

/*
	Grant execute permission to created users
*/
GRANT EXECUTE ON SCHEMA::[web] TO [NodeFuncApp];
GO

/*
	Return details on a specific customer
*/
CREATE OR ALTER PROCEDURE web.get_customer
@Json NVARCHAR(MAX)
AS
SET NOCOUNT ON;
DECLARE @CustomerId INT = JSON_VALUE(@Json, '$.CustomerId');
SELECT 
	[CustomerId], 
	[Name], 
	[Location] AS 'Delivery.Location', 
	[Email] AS 'Delivery.Email'
FROM 
	[dbo].[Customers] 
WHERE 
	[CustomerId] = @CustomerId
FOR JSON PATH
GO

/*
	Delete a specific customer
*/
CREATE OR ALTER PROCEDURE web.delete_customer
@Json NVARCHAR(MAX)
AS
SET NOCOUNT ON;
DECLARE @CustomerId INT = JSON_VALUE(@Json, '$.CustomerID');
DELETE FROM [Sales].[Customers] WHERE CustomerId = @CustomerId;
SELECT * FROM (SELECT CustomerID = @CustomerId) D FOR JSON AUTO;
GO

/*
	Update (Patch) a specific customer
*/
CREATE OR ALTER PROCEDURE web.patch_customer
@Json NVARCHAR(MAX)
AS
SET NOCOUNT ON;
DECLARE @CustomerId INT = JSON_VALUE(@Json, '$.CustomerID');
WITH [source] AS 
(
	SELECT * FROM OPENJSON(@Json) WITH (
		[CustomerID] INT, 
		[CustomerName] NVARCHAR(100), 
		[PhoneNumber] NVARCHAR(20), 
		[FaxNumber] NVARCHAR(20), 
		[WebsiteURL] NVARCHAR(256),
		[DeliveryAddressLine1] NVARCHAR(60) '$.Delivery.AddressLine1',
		[DeliveryAddressLine2] NVARCHAR(60) '$.Delivery.AddressLine2',
		[DeliveryPostalCode] NVARCHAR(10) '$.Delivery.PostalCode'	
	)
)
UPDATE
	t
SET
	t.[CustomerName] = COALESCE(s.[CustomerName], t.[CustomerName]),
	t.[PhoneNumber] = COALESCE(s.[PhoneNumber], t.[PhoneNumber]),
	t.[FaxNumber] = COALESCE(s.[FaxNumber], t.[FaxNumber]),
	t.[WebsiteURL] = COALESCE(s.[WebsiteURL], t.[WebsiteURL]),
	t.[DeliveryAddressLine1] = COALESCE(s.[DeliveryAddressLine1], t.[DeliveryAddressLine1]),
	t.[DeliveryAddressLine2] = COALESCE(s.[DeliveryAddressLine2], t.[DeliveryAddressLine2]),
	t.[DeliveryPostalCode] = COALESCE(s.[DeliveryPostalCode], t.[DeliveryPostalCode])
FROM
	[Sales].[Customers] t
INNER JOIN
	[source] s ON t.[CustomerID] = s.[CustomerID]
WHERE
	t.CustomerId = @CustomerId;

DECLARE @Json2 NVARCHAR(MAX) = N'{"CustomerID": ' + CAST(@CustomerId AS NVARCHAR(9)) + N'}'
EXEC web.get_customer @Json2;
GO

/*
	Create a new customer
*/

CREATE OR ALTER PROCEDURE web.put_customer
@Json NVARCHAR(MAX)
AS
SET NOCOUNT ON;
DECLARE @CustomerId INT = NEXT VALUE FOR Sequences.CustomerID;
WITH [source] AS 
(
	SELECT * FROM OPENJSON(@Json) WITH (		
		[CustomerName] NVARCHAR(100), 
		[PhoneNumber] NVARCHAR(20), 
		[FaxNumber] NVARCHAR(20), 
		[WebsiteURL] NVARCHAR(256),
		[DeliveryAddressLine1] NVARCHAR(60) '$.Delivery.AddressLine1',
		[DeliveryAddressLine2] NVARCHAR(60) '$.Delivery.AddressLine2',
		[DeliveryPostalCode] NVARCHAR(10) '$.Delivery.PostalCode'	
	)
)
INSERT INTO [Sales].[Customers] 
(
	CustomerID, 
	CustomerName, 	
	BillToCustomerID, 
	CustomerCategoryID,	
	PrimaryContactPersonID,
	DeliveryMethodID,
	DeliveryCityID,
	PostalCityID,
	AccountOpenedDate,
	StandardDiscountPercentage,
	IsStatementSent,
	IsOnCreditHold,
	PaymentDays,
	PhoneNumber, 
	FaxNumber, 
	WebsiteURL, 
	DeliveryAddressLine1, 
	DeliveryAddressLine2, 
	DeliveryPostalCode,
	PostalAddressLine1, 
	PostalAddressLine2, 
	PostalPostalCode,
	LastEditedBy
)
SELECT
	@CustomerId, 
	CustomerName, 
	@CustomerId, 
	5, -- Computer Shop
	1, -- No contact person
	1, -- Post Delivery 
	28561, -- Redmond
	28561, -- Redmond
	SYSUTCDATETIME(),
	0.00,
	0,
	0,
	30,
	PhoneNumber, 
	FaxNumber, 
	WebsiteURL, 
	DeliveryAddressLine1, 
	DeliveryAddressLine2, 
	DeliveryPostalCode,
	DeliveryAddressLine1, 
	DeliveryAddressLine2, 
	DeliveryPostalCode,
	1 
FROM
	[source]
;

DECLARE @Json2 NVARCHAR(MAX) = N'{"CustomerID": ' + CAST(@CustomerId AS NVARCHAR(9)) + N'}'
EXEC web.get_customer @Json2;
GO

CREATE OR ALTER PROCEDURE web.get_customers
AS
SET NOCOUNT ON;
-- Cast is needed to simplify JSON management on the client side:
-- https://docs.microsoft.com/en-us/sql/relational-databases/json/use-for-json-output-in-sql-server-and-in-client-apps-sql-server
-- as a single JSON result can be returned as chunked into several rows. By casting it into a NVARCHAR(MAX) it will always be
-- returned as one row instead (but with a 2GB limit...which shouldn't be a problem.)
SELECT CAST((
	SELECT 
		[CustomerID], 
		[CustomerName]
	FROM 
		[Sales].[Customers] 
	FOR JSON PATH) AS NVARCHAR(MAX)) AS JsonResult
GO

