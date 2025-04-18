# Smash Events

## Run locally

### Initialize the database (first run)

```
docker compose run web sh
rails db:setup
```

### Run the app

```
docker compose up
```

or

```
docker compose run --service-ports web sh
rails s -b0
```

### Console

```
docker compose exec web rails c
```

### Populate the database

```
rails startgg:sync
```
