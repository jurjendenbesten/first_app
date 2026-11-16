# First App — Veldapp voor leidingwerkzaamheden

Cross-platform app (iOS + Android, gebouwd met **Flutter**) voor monteurs die
leidingnetwerk-werkzaamheden uitvoeren:

- **Kaart** met leidingen, afsluiters en brandkranen (OpenStreetMap, geen API-key nodig)
- **Opdrachten** ontvangen en uitvoeren:
  1. Afsluiters open zetten en rapporteren (gelukt / niet gelukt + opmerking)
  2. Zodra alle afsluiters open staan: een of meer brandkranen open zetten
  3. Per brandkraan rapporteren of het openen lukte
  4. Visuele waterkwaliteit rapporteren (goed / matig / slecht) en
     troebelheidsmetingen (NTU) vastleggen
- Koppeling met de **Blazor web applicatie** via een REST API

## Snel starten (vereist Flutter SDK, zie https://docs.flutter.dev)

De platformmappen (`android/`, `ios/`) worden door Flutter gegenereerd:

```bash
flutter create .          # genereert android/ en ios/ (overschrijft lib/ niet)
flutter pub get
flutter run               # start in demo-modus met mock-data
```

### Koppelen aan de backend

Standaard wijst de app naar `http://10.0.2.2:5000` (localhost van de
ontwikkelmachine, gezien vanuit de Android-emulator). Voor productie:

```bash
flutter run --dart-define=API_BASE_URL=https://jouw-blazor-server
```

Demo-modus (mock-data, geen backend nodig) staat nu aan in
`lib/main.dart` (`createApiClient(useMock: true)`). Zet dit op `false`
zodra de Blazor-backend de endpoints hieronder aanbiedt.

## REST API-contract (te implementeren in / door de Blazor-app)

De app praat met een ASP.NET Core backend (de Blazor-server kan deze
endpoints direct in `Program.cs` aanbieden met Minimal APIs).

| Methode | Endpoint | Body / response |
|---|---|---|
| GET | `/api/network` | `{ pipes: [{id, name, diameterMm, points: [{latitude, longitude}]}], valves: [{id, name, latitude, longitude, status}], hydrants: [{id, name, latitude, longitude, status}] }` |
| GET | `/api/workorders` | `{ workOrders: [WorkOrder] }` |
| POST | `/api/workorders/{id}/valves/{valveId}/operation` | `{ valveId, success, note, timestamp, technician }` |
| POST | `/api/workorders/{id}/hydrants/{hydrantId}/operation` | `{ hydrantId, success, note, timestamp, technician }` |
| POST | `/api/workorders/{id}/hydrants/{hydrantId}/quality` | `{ hydrantId, visualQuality: "good"\|"moderate"\|"poor", turbidityNtu, notes, timestamp }` |

- `status` van een asset: `"unknown"`, `"closed"` of `"open"`
- `WorkOrder`: `{ id, title, description, technician, status (0–3), valves, hydrants }`
  met status 0 = toegewezen, 1 = in uitvoering, 2 = afsluiters klaar, 3 = voltooid

### Voorbeeld Minimal API in de Blazor-server

```csharp
app.MapGet("/api/workorders", () => Results.Json(new { workOrders = db.WorkOrders }));
app.MapPost("/api/workorders/{id}/valves/{valveId}/operation",
    (string id, string valveId, ValveOperationDto dto) => { /* opslaan */ Results.Ok(); });
```

## Projectstructuur

```
lib/
├── main.dart                     # app-entrypoint
├── models/models.dart            # WorkOrder, Valve, Hydrant, Pipe, QualityReport
├── services/api_service.dart     # REST-client + mock-client (demo)
├── state/work_order_store.dart   # app-state (ChangeNotifier + provider)
└── screens/
    ├── home_screen.dart          # navigatie (Kaart / Opdrachten)
    ├── map_screen.dart           # kaart met leidingen, afsluiters, brandkranen
    ├── work_orders_screen.dart   # opdrachtenlijst
    └── order_detail_screen.dart  # uitvoerflow + rapportageschermen
```
