# Mobile Application
Struttura dell’applicazione mobile:

![image.png](https://github.com/cartaphilvss/AccessControlSystem/blob/main/assets/imgs/MobileApplicationStructure.drawio.png)

## Le pagine

Ciascuna delle pagine ha un ViewModel associato che si occupa di tutta la logica di funzionamento. Ecco cosa fa ciascuna della pagine: 
- Main Page: definisce il layout/struttura di tutta l’applicazione e carica la Loading Page prima di tutte le altre.
- Loading Page: verifica che l’utente sia gia’ loggato grazie alla classe ausiliaria ```Settings Controller``` che utilizza al proprio interno la classe `Preferences` del plugin [Xamarin.Essentials](https://docs.microsoft.com/it-it/xamarin/essentials/?context=xamarin%2Fandroid) per mantenere persistenti le preferenze/impostazioni dell'utente. La funzione che si occupa di verificare lo stato del login e’ `Init()`:
```
public async Task Init()
        {

            // Per via di un bug che chiama due volte la funzione OnAppearing nel LoadingPage.xaml e' stata aggiunta una variabile count
            // che si occupa di verificare che la funzione non venga chiamata piu' di due volte.
            if (cnt++ != 0) return;
            
            
            // Grazie alle classe ausiliaria SettingsController verifichiamo se l'utente e' gia' loggato
            // La funzione Shell.Current.GoToAsync() ci permette di muoverci tra le pagine definite nel MainPage.xaml
            if (SettingsController.isAutenticated() == "True")
            {
                await Shell.Current.GoToAsync("///main");
                
            }else
            {
                await Shell.Current.GoToAsync("///login");
            }
        }
```
- Login Page: permette all’utente di loggare tramite un Token fornito dall'amministratore del sistema. Il Token viene inviato tramite un GET request all’API `/api/AccessToken/Token/{token}`  che ritorna niente nel caso il Token non sia presente nel DB, altrimenti ritorna il TokenModel che contiene il Token. Nel caso di esito positivo l’utente verra’ spostato in `Main Page Content` e verranno prese le informazioni dell’utente dalla Web Application a partire dallo userId contenuto nel TokenModel. Se l’esito e’ negativo verra’ mostrato un messaggio di errore nella pagina di login.
```
private async void OnLoginSystem()
        {
            HttpServices auth = new HttpServices();
            bool result = await auth.validateToken(LoginToken);
            if (result)
            {
                Debug.WriteLine("Autentication is completed", "Autentication System");
                SettingsController.setAutentication();
                await Shell.Current.GoToAsync("///main");
            }
            else {
                ErrorMessage = "Password non corretta";
                Debug.WriteLine($"La password e' sbagliata", "Autentication System");
                LoginToken = "";
            }

        }
```
- Logs Page: mostra una lista di logs dell’utente con le seguenti informazioni: data e nome del sensore.
- Main Page Content: e’ una welcome page che mostra un messaggio di benvenuto all’utente.
- Badge Page: gestisce l’interazione con il tag NFC e comunica con la Web Application per verificare l’accesso dell’utente. Piu’ informazione nella sezione successiva.

## Near Field Communication (NFC)
Il Near Field Communication è una tecnologia di ricetrasmissione che fornisce connettività contactless senza fili bidirezionale a distanza a corto raggio. Viene utilizzata principalmente per i pagamenti contactless e l’autenticazione per servizi di ticketing o controllo di accesso. Le principali modalita’ operative del NFC sono 3:
- Reader/Write mode
- Card Emulation mode
- Peer-to-Peer mode

La modalita’ che abbiamo usata noi per la realizzazione del sistema di accesso e’ il Reader/Write mode che descrive l’interazione tra un device NFC e un tag passivo NFC. Quando il device NFC, nel nostro caso il telefono dell’utente, entra nel raggio operativo del tag NFC, inizializza una connessione con il tag e avviene uno scambio di comandi NFC con il chip presente all’interno del tag per svolgere operazioni di lettura e scrittura. Lo stato del tag viene ripristinato quando il device NFC esce dal raggio operativo del tag. La Badge Page dell’applicazione si occupa di leggere il tag passivo che contiene l’identificativo associato ad un sensore. Una volta letto l’identificativo vengono inviati due informazioni tramite POST request all’API */api/Badges*: l’ID dell’utente e l’identificativo. L’API elabora la richiesta, invia all’apposito sensore l’esito e crea un log nel database.  L’implementazione della tecnologia Near Field Communication all’interno dell’applicazione e’ stata fatta con il plugin [Plugin.NFC](https://github.com/franckbour/Plugin.NFC) per Xamarin.Forms, scaricabile attraverso il NuGet Package Manager per Visual Studio.

# Sensore 
Il sensore e’ [NodeMCU ESP8266 ESP12-E Amica v2](https://www.amazon.it/AZDelivery-NodeMCU-esp8266-esp-12e-gratuito/dp/B06Y1LZLLY/ref=sr_1_3?__mk_it_IT=%C3%85M%C3%85%C5%BD%C3%95%C3%91&crid=4EQXZV5P4QEI&keywords=nodemcu+esp8266+amica+v2&qid=1655200180&s=pc&sprefix=nodemcu+esp8266+amica+v2%2Ccomputers%2C85&sr=1-3) una scheda di sviluppo Open Source utilizzata principalmente per dispositivi IOT. 
Questi sono i pin di uscita della scheda:

![image.png](https://github.com/cartaphilvss/AccessControlSystem/blob/main/assets/imgs/NodeMCU-ESP8266-Pinout.jpg)

Per ulteriori informazioni fare riferimento al datasheet del [ESP8266](https://espressif.com/sites/default/files/documentation/0a-esp8266ex_datasheet_en.pdf) o la [Documentazione NodeMCU](https://nodemcu.readthedocs.io/en/release/).

## Premessa
Prima di poter eseguire il codice relativo al sensore bisogna prima installare Arduino IDE e le librerie per il chip ESP8266. Una guida completa la trovate a questo [link](https://randomnerdtutorials.com/how-to-install-esp8266-board-arduino-ide/). Bisogna installare anche la libreria ArduinoJson che si puo’ scaricare da `Sketch > #include Libreria > Gestione Librerie`.

Versioni utilizzate:
- ESP8266 board [3.0.0]
- Arduino_JSON  [0.1.0]

### Funzionamento
Lo schema circuitale del sensore e’ molto semplice:

![image.png](https://github.com/cartaphilvss/AccessControlSystem/blob/main/assets/imgs/circuit%20design.png)

Prima di tutto il microcontrollore deve avere accesso alla rete quindi inizializziamo la connessione nella funzione Setup(), la prima funzione chiamata dal microcontrollore al momento dell’accensione. Il codice che inizializza la connessione al Wi-Fi e’ il seguente: 
```void initWiFi()
{
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED)
  {
    delay(500);  
    Serial.print("*");
  }
  // General info start up 
  Serial.println("\nWiFi connection successful");
  Serial.print("IP address: ");
  Serial.println(WiFi.localIP());  
}
```

E’ importante salvare l’indirizzo IP del dispositivo perche’ ci servira’ dopo per poter pubblicare il Web Server su internet.
I parametri utilizzati in `WiFi.begin()` sono due variabili globali dichiarate precedentemente che contengono SSID del Wi-Fi e

la password per potersi connettere. La funzione principale del microcontrollore e’ quella di Web Server collegato alla porta 8888 con una singola API `/api/access` accessibile tramite una POST request che contiene l’esito dell’accesso elaborato dalla WebApplication. Il codice che gestisce le richieste e’ il seguente: 

```void accessDevice()
{
    
    String postBody = server.arg("plain");
    Serial.println(postBody);
    // Controlla la stringa contenuta nella POST request
    if(postBody == "True")
    {
      server.send(200, "text/plain", "Accesso Confermato");
      accessAllowed();
    } else {
      server.send(404, "text/plain", "Accesso Vietato");
      accessDenied();  
    }
}
```

Le funzione `accessAllowed()` e `accessDenied()` non fanno che altro che accendere rispettivamente il led Verde e il led Rosso per circa 3000 millisecondi.  

## Ngrok
Il Web Server e’ accessibile soltanto in rete locale, quindi e’ necessario uno strumento che permetta di esporre il nostro server locale su internet, ovvero [ngrok](https://ngrok.com/). Per poter utilizzare ngrok è necessario registrarsi sul loro sito e [scaricare l’applicazione](https://ngrok.com/download). Per prima cosa tramite command-line andremo ad aggiungere l’Authtoken alla configurazione del programmma tramite questo comando: 

```
ngrok config add-authtoken {iltuotoken}
``` 

Una volta configurato, bisognera’ soltanto pubblicare il nostro Web Server con questo comando: 

```
ngrok http {indirizzoMicrocontrollore}:{porta}
```

Sulla voce ‘Forwarding’ ci sara’ URL che ci permettera’ di accedere dal browser e chiamare l’API dalla WebApplication.



<h3>Database</h3>

```
dbo
├── Tables
└── StoredProcedures
```

---

Il campo `GroupId` contenuto nelle tabelle [User]() e [Sensor]() permette di identificare i permessi di accesso degli utenti.
La tabella [Group]() rappresenta i permessi del sistema.
```SQL
CREATE TABLE [dbo].[Group] (
    [id] INT NOT NULL PRIMARY KEY IDENTITY (1,1),
    [name] NVARCHAR (MAX) NOT NULL
);

CREATE TABLE [dbo].[User]
(
    [id] INT NOT NULL PRIMARY KEY IDENTITY (1,1),
    [name] NVARCHAR (MAX) NOT NULL,
    [surname] NVARCHAR (MAX) NOT NULL,
    [phone] NVARCHAR (MAX) NOT NULL,
    [email] NVARCHAR (MAX) NOT NULL,
    [gender] NVARCHAR (MAX),
    [group_id] INT NOT NULL # FOREIN KEY
);

CREATE TABLE [dbo].[Sensor]
(
    [id] INT NOT NULL PRIMARY KEY IDENTITY (1,1),
    [name] NVARCHAR (MAX) NOT NULL,
    [group_id] INT NOT NULL, # FOREIN KEY
    [nfc_tag] NVARCHAR (MAX) NOT NULL
);


```

I campi `UserId` e `NFC_Tag` della tabella [Badge]() consentono di ottenere, tramite le apposite API, i record degli utenti e sensori coinvolti nella comunicazione.
```SQL
CREATE TABLE [dbo].[Badge] (
    [id] INT NOT NULL PRIMARY KEY IDENTITY (1,1),
    [user_id] INT NOT NULL,
    [nfc_tag] NVARCHAR(MAX) NOT NULL
);
```

La tabella [Log]() permette di tenere traccia di tutti gli accessi effettuati nel sistema.
```SQL
CREATE TABLE [dbo].[Log]
(
    [id] INT NOT NULL PRIMARY KEY IDENTITY (1,1),
    [user_id] INT NOT NULL,
    [sensor_id] INT NOT NULL,
    [date_time] DATETIME NOT NULL
)
```

La tabella [AccessToken]() contiene il campo `Token` che consente l'accesso all'applicazione mobile.
```SQL
CREATE TABLE [dbo].[AccessToken]
(
	[id] INT NOT NULL PRIMARY KEY IDENTITY (1,1),
	[token] NVARCHAR (MAX) NOT NULL, # Chiave di acesso Mobile Application
	[userId] INT NOT NULL
)
```

```
Tables
├── AccessToken.sql
├── Badge.sql
├── Group.sql
├── Log.sql
├── Sensor.sql
└── User.sql
```

IL database è stato realizzato tramite il BDMS [Microsoft SQL Server](https://docs.microsoft.com/it-it/sql/ssms/download-sql-server-management-studio-ssms?view=sql-server-ver16), i [Server Data Tools for Visual Studio](https://docs.microsoft.com/it-it/sql/ssdt/download-sql-server-data-tools-ssdt?view=sql-server-ver16) ed il linguaggio [Transact-SQL](https://docs.microsoft.com/it-it/sql/t-sql/language-reference?view=sql-server-ver16)

Oltre agli script di creazione ed eliminazione del Database e delle Tabelle, rispettivamente [CREATE]() e [DELETE](), vengono implementate le [Stored Procedures]() per le operazioni [CRUD]().
```SQL
# Esempi:
CREATE PROCEDURE [dbo].[insertUser]
	@Name NVARCHAR (MAX),
	@Surname NVARCHAR (MAX),
	@Phone NVARCHAR (MAX),
	@Email NVARCHAR (MAX),
	@Gender NVARCHAR (MAX),
	@GroupId INT
AS
BEGIN
	INSERT INTO [User]
	([name], [surname], [phone], [email], [gender], [group_id])
	VALUES 
	(@Name, @Surname, @Phone, @Email, @Gender, @GroupId);
END

CREATE PROCEDURE [dbo].[deleteGroup]
	@Id INT
AS
BEGIN
	SET NOCOUNT ON;
	DELETE FROM [Group]
	WHERE [id] = @Id;
END
```

```
Stored Procedures
├── deleteAccessToken.sql
├── deleteBadge.sql
├── deleteGroup.sql
├── deleteLog.sql
├── deleteSensor.sql
├── deleteUser.sql
├── getAccessTokenById.sql
├── getAccessTokenByToken.sql
├── getAccessTokens.sql
├── getBadgeById.sql
├── getBadgeByNFCTag.sql
├── getBadges.sql
├── getGroupById.sql
├── getGroupByName.sql
├── getGroups.sql
├── getLogById.sql
├── getLogs.sql
├── getLogsByDateTime.sql
├── getLogsBySensorId.sql
├── getLogsByUserId.sql
├── getSensorById.sql
├── getSensorByNFCTag.sql
├── getSensors.sql
├── getUserById.sql
├── getUsers.sql
├── insertAccessToken.sql
├── insertBadge.sql
├── insertGroup.sql
├── insertLog.sql
├── insertSensor.sql
├── insertUser.sql
├── updateAccessToken.sql
├── updateBadge.sql
├── updateGroup.sql
├── updateLog.sql
├── updateSensor.sql
└── updateUser.sql
```

L’interfaccia [ISQLDataAccess](), tramite i metodi [LoadData] e [SavaData], permette di accedere al database.
```cs
public class SQLDataAccess : ISQLDataAccess
{
    private readonly IConfiguration _configuration;
    public SQLDataAccess(IConfiguration configuration)
    {
        _configuration = configuration;
    }
    public async Task<IEnumerable<T>> LoadData<T, U>(stringstoredProcedure, U parameters, string connectionId = "Default")
    {
        using DbConnection connection = new SqlConnectio(_configuration.GetConnectionString(connectionId));
        return await connection.QueryAsync<T>(storedProcedure,parameters, commandType: CommandType.StoredProcedure);
    }
    public async Task SaveData<T>(string storedProcedure, Tparameters, string connectionId = "Default")
    {
        using DbConnection connection = new SqlConnectio(_configuration.GetConnectionString(connectionId));
        await connection.ExecuteAsync(storedProcedure, parameters,commandType: CommandType.StoredProcedure);
    }
}
```
I metodi accettano come parametri:
- `Nome della Stored Procedure` 
- `Parametri della Stored Procedure`
- `ConnectionString al Database`

La comunicazione con il database avviene mediante le [Stored Procedures] che consentono al framework [Draper]() di realizzare metodi per la gestione delle operazione [CRUD].

[Tabelle presenti nel database]() vengono rappresentate dai loro singoli [Modelli]().
I [DataModel]() implementano i metodi: { `get`, `getAll`, `insert`, `update`, `delete` } per le operazioni [CRUD]. Ogni DataModel presenta una propria Interfaccia [IDataModel]() che lavora sul [Model]() ad esso associato.
```cs
    # Esempio Modello:
    public class UserModel : CreateUserModel
    {
        public int Id { get; set; }
    }

    public class CreateUserModel
    {
        public string? Name { get; set; }
        public string? Surname { get; set; }
        public string? Phone { get; set; }
        public string? Email { get; set; }
        public string? Gender{ get; set; }
        public int GroupId { get; set; }
    }

# DataModel implementa la propria Interfaccia
public class UserData : IUserData
{
    private readonly ISQLDataAccess _dataBase;
    public UserData(ISQLDataAccess dataBase) { _dataBase = dataBase; }
    public Task<IEnumerable<UserModel>> GetUsers()
    {
        return _dataBase.LoadData<UserModel, dynamic>("dbo.getUsers",new { });
    }
    public async Task<CreateUserModel?> GetUser(int id)
    {
        var results = await _dataBase.LoadData<CreateUserModel,dynamic>("dbo.getUserById", new { Id = id });
        return results.FirstOrDefault();
    }
    public Task InsertUser(CreateUserModel user)
    {
        return _dataBase.SaveData("dbo.insertUser", user);
    }
    public Task UpdateUser(UserModel user)
    {
        return _dataBase.SaveData("dbo.updateUser", user);
    }
    public Task DeleteUser(int id)
    {
        return _dataBase.SaveData("dbo.deleteUser", new { Id = id });
    }
}
```

In `Program.cs`
```cs
builder.Services.AddSingleton<ISQLDataAccess, SQLDataAccess>();
builder.Services.AddSingleton<IModelData, ModelData>();

...
```
# MINIMAL REST APIs
![Swagger UI]()

Realizzazione delle API mediante l'[Open API (Swagger)]()
Documentazione delle API mediante [Swagger UI]()

Nel metodo `ConfigureAPI` si specifica il tipo di [Richiesta HTTP](), si associa l’`URL` della richiesta ed il `Metodo di Callback` da eseguire.
```cs
app.Method(URL, CallbackMethod);
```

Le API vengono gestite nella classe [API]():
```cs
private static readonly string _apiBaseUrl = "/api";
public static void ConfigureAPI(this WebApplication app)
{
    app.MapGet(_apiBaseUrl + "/Users", GetUsers);
    app.MapGet(_apiBaseUrl + "/Users/{id}", GetUser);
    app.MapPost(_apiBaseUrl + "/Users", InsertUser);
    app.MapPut(_apiBaseUrl + "/Users", UpdateUser);
    app.MapDelete(_apiBaseUrl + "/Users", DeleteUser);
    .
    .
    .
}
```

In `Program.cs`
```cs
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

...

app.UseSwagger(); 
app.UseSwaggerUI();  

app.UseHttpsRedirection();
app.ConfigureAPI();

...

app.Run();
```





