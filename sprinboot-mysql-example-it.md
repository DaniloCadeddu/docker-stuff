# Sistema a due container MySQL database + SpringBoot backend

## Approccio base

Supponiamo di dover creare un sistema a due container. Un container conterrá un’immagine di una applicazione SpringBoot che monterá (tipologia bind) una cartella per dei file di log. Il secondo container conterrá un’immagine di MySQL 8 che monterá rispettivamente una cartella per i dati e una per i log. Infine i due container apparterranno alla stessa sottorete in modo tale da far comunicare il backend SpringBoot al database MySQL.

### Creare la rete

Iniziamo con creare una rete

```bash
docker network create my-network
```

questo comando creerá una nuova rete dal nome my-network. Per verificare che la rete sia stata creata correttamente scrivere

```bash
docker network ls
```

il comando mostrerá una lista delle sottoreti docker e l’output sará del tipo

```bash
NETWORK ID     NAME             DRIVER    SCOPE
a0788939969f   bridge           bridge    local
159ff90c9984   host             host      local
7cda0ea85de9   kong-net         bridge    local
25e19f4d0da1   none             null      local
a5859e5c9a5a   **my-network**       bridge    local
```

### Creare il container MySQL

Creiamo e facciamo partire un container MySQL. Potenzialmente è possibile fare tutto con il singolo comando `run` come di seguito

```bash
docker run --name mysql-8 \
-v /opt/mysql/data:/var/lib/mysql \
-v /opt/mysql/log:/var/log/mysql \
--network my-network \
--network-alias mysql -d -p 3306:3306 -e "MYSQL_ROOT_PASSWORD=root" -e "MYSQL_DATABASE=mydb" mysql:8.0
```

questo comando per prima cosa verifica se abbiamo giá scaricato in precedenza un’immagine di mysql-8 se non l’abbiamo fatto docker scaricherá dal suo registro remoto l’immagine in questione altrimenti userá l’immagine locale per iniziare a costruire il container.

Con l’opzione `--name` specifichiamo un nome a piacere da dare al nuovo container.

Con il flag `-v` chiediamo a docker di fare una bind mount con la macchina host. La sintassi è del tipo **<PATH_FOLDER_HOST>:<PATH_FOLDER_CONTAINER>.** Ogni modifica su una di queste cartelle verrá riflessa nell’altra e viceversa.

Con l’opzione `--network` diciamo a docker di inserire il nuovo container alla sottorete privata **my-network** assegnandoli quindi un proprio IP privato, con l’opzione `--network-alias` specifichiamo l’alias del container nella rete, in questo modo, docker a partire dall’alias **mysql** riuscirá a risolvere l’alias nell’IP del container.

Il flag `-d` ci permette di far partire il container in background (“detached” mode).

Il flag `-p` ci permette di mappare una porta della macchina host con una porta del container. In questo caso per mysql andremo ad utilizzare la porta di default 3306 sia per l’host che per il container.

Il flag `-e` aggiunge delle variabili d’ambiente al container, in questo caso andiamo a specificare la password dell’utente root e il nome del database da creare.

Specifichiamo infine l’immagine da usare per creare il container.

Per verificare che il container si sia stato creato correttamente ed è attivo, scrivere

```bash
docker ps
```

mostrerá una lista dei container attivi con output del tipo

```bash
CONTAINER ID   IMAGE     COMMAND                  CREATED        STATUS         PORTS                               NAMES
909a1b53a926   mysql:8   "docker-entrypoint.s…"   19 hours ago   Up 8 seconds   0.0.0.0:3306->3306/tcp, 33060/tcp   mysql-8
```

se volessimo spawnare una shell bash nel container appena creato

```bash
docker exec -it mysql-8 bash
```

entrati nel container accediamo alla shell di mysql

```bash
mysql -uroot -p
```

MySQL ci chiederà di inserire la password, che sarà quella specificata nella variabile d’ambiente MYSQL_ROOT_PASSWORD usata nella creazione del container.

### Creare il container per il backend SpringBoot

Per creare inzialmente un’immagine per l’applicazione SpringBoot usiamo un semplice Dockerfile del tipo

```docker
FROM maven:3.8.6-jdk-1

COPY . /myapp
WORKDIR /myapp

RUN mvn clean install -DskipTests

ENTRYPOINT ["java", "-jar", "/myapp/target/springbootapp.jar"]
```

`FROM maven:3.8.6-jdk-11` con questa istruzione specifichiamo l’immagine docker di base su cui baseremo la nostra immagine.

`COPY . /myapp` copiamo il contenuto della cartella della macchina host in una cartella /myapp nel container.

`WORKDIR /myapp` mettiamo come folder di lavoro la cartella appena creata

`RUN mvn clean install -DskipTests` con questo comando lanciamo la build maven che creerà la cartella target nella root directory con all’interno il jar dell’applicazione java.

`ENTRYPOINT ["java", "-jar", "/myapp/target/springbootapp.jar"]` con questo istruzione andiamo a eseguire il comando `java -jar` 

`/myapp/target/springbootapp.jar` in modo tale da far partire automaticamente l’applicazione quando andremo poi a costruire il container con questa immagine.

Scritto il Dockerfile non dobbiamo fare altro che buildare l’immagine con il comando

```bash
docker build /path/to/Dockerfile -t <MY_IMAGE_NAME>:<MY_IMAGE_VERSION>
```

il flag `-t` permette di taggare dando quindi un nome all’immagine, e dopo i `:` , una versione, che se ommessa sará “latest”.

Per verificare che l’immagine è stata creata correttamente

```bash
docker images
```

mostrerá la lista delle immagini docker locali con output del tipo

```bash
REPOSITORY          TAG              IMAGE ID       CREATED        SIZE
MY_IMAGE_NAME       MY_IMAGE_VERSION 4609abc147da   1 hours ago   741MB
```

Prima di costruire il container è importante vedere l’application.properties del progetto SpringBoot

```
spring.datasource.url=jdbc:mysql://**mysql**:**3306**/mydb
spring.datasource.username=root
spring.datasource.password=root
spring.datasource.driver-class-name=com.mysql.cj.jdbc.Driver
```

in questo caso avendo messo mysql come network alias al container con MySQL lo useremo come host nel datasource url. Docker in automatico crea come alias l’id container, permettendo quindi di usarlo come hostname. Se non avessimo usato un network alias avremmo dovuto recuperare l’IP del container con MySQL per esempio nel seguente modo

```bash
docker inspect <CONTAINER_NAME>
```

l’output del comando è un json contenente la configurazione del container.

Non resta altro che costruire il container.

```bash
docker run --name MY_CONTAINER_NAME --network my-network \
-v /path/to/logs:/var/log/whatever \
--network-alias MY_CONTAINER_ALIAS -d -p 8080:8080 MY_IMAGE_NAME
```

con sintassi equivalente al comando usato per il container MySQL.

Se tutto è andato bene, il container SpringBoot risponderá alla porta 8080 e comunicherá con il container MySQL alla 3306.

## Approccio docker compose

L’approccio con docker compose ci permette di creare un singolo file yaml che si occuperà di creare automaticamente sia il container con MySQL che quello con l’applicazione SpringBoot.

In questo caso il `docker-compose.yml` sarà del tipo:

```yaml
version: "3.7"

services:
  mysql:
    image: mysql:8.0
    environment:
      - MYSQL_ROOT_PASSWORD=root
      - MYSQL_DATABASE=mydb
    ports:
      - "3306:3306"

  springboot:
    build: .
    restart: on-failure
    ports:
      - "8080:8080"
```

`version` specifica la versione dello schema del docker compose file.

Dentro la proprietà `services` avremo le definizioni dei container che verranno creati.

Partendo dal primo servizio `mysql`, la proprietà `image` permette di specificare l’immagine docker usata per creare il container. Con `enviroments` definiamo le variabili d’ambiente e con `ports` le porte da mappare tra il container e l’host.

Con il secondo service `springboot` supponendo di non avere un immagine pubblica dell’applicazione ma di dover usare il Dockerfile scritto per il punto precedente nell’approccio base, possiamo specificare con la prop `build` un path alla folder che contiene il Dockerfile su cui basare l’immagine. 

Con `restart: on-failure` ci assicuriamo che il container con l’app SpringBoot riparta nel caso di fallimento, poichè è possibile che il container con MySQL potrebbe partire qualche istante dopo.

A partire dalla folder con il `docker-compose.yml` eseguire il comando:

```bash
docker-compose up -d --build
```

che ci permette di buildare le immagini coinvolte `--build` di tirare su i container in detach mode.

È importante notare che docker-compose creerà in automatico una rete di default con ogni services al suo interno che avranno come alias il nome del service stesso.

Se tutto è andato correttamente Spring risponderà all’8080 e MySQL alla 3306.

Per stoppare e rimuovere i container eseguire il comando:

```bash
docker-compose down
```