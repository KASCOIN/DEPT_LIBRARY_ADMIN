# Data Viewing Links

## Admin Interface
Access the admin panel at:
```
http://localhost:8000/admin.html
```

## Timetable Viewing Links

View timetable for each programme and level combination via API:

**Meteorology**
- Level 100: `http://localhost:8000/api/admin/timetable?programme=Meteorology&level=100`
- Level 200: `http://localhost:8000/api/admin/timetable?programme=Meteorology&level=200`
- Level 300: `http://localhost:8000/api/admin/timetable?programme=Meteorology&level=300`
- Level 400: `http://localhost:8000/api/admin/timetable?programme=Meteorology&level=400`
- Level 500: `http://localhost:8000/api/admin/timetable?programme=Meteorology&level=500`

**Geography**
- Level 100: `http://localhost:8000/api/admin/timetable?programme=Geography&level=100`
- Level 200: `http://localhost:8000/api/admin/timetable?programme=Geography&level=200`
- Level 300: `http://localhost:8000/api/admin/timetable?programme=Geography&level=300`
- Level 400: `http://localhost:8000/api/admin/timetable?programme=Geography&level=400`
- Level 500: `http://localhost:8000/api/admin/timetable?programme=Geography&level=500`

## Courses Viewing Links

View all stored courses via API:
```
http://localhost:8000/api/admin/courses
```

The courses are stored organized by programme and level in the JSON response. Use the admin panel to view and edit courses for each programme/level combination:

1. Go to [http://localhost:8000/admin.html](http://localhost:8000/admin.html)
2. Navigate to the **Manage Courses** section
3. Select Programme (Meteorology or Geography)
4. Select Level (100, 200, 300, 400, or 500)
5. Edit courses and click **Save Courses**

## Timetable Management

Similarly for timetable:

1. Go to [http://localhost:8000/admin.html](http://localhost:8000/admin.html)
2. Navigate to the **Manage Timetable** section
3. Select Programme (Meteorology or Geography)
4. Select Level (100, 200, 300, 400, or 500)
5. Add time slots (code, title, time, duration, venue, lecturer)
6. Data auto-saves with each change

## Features

### Courses Form
- **Programme**: Select between Meteorology or Geography
- **Level**: Select from 100, 200, 300, 400, or 500
- **Course Advisor Name**: Enter the name of the course advisor
- **Up to 15 Courses**: Each course can be marked as **Compulsory** or **Elective** using radio buttons
- **Lecturer Fields**: Up to 3 lecturers per course
- **Auto-save**: Changes are automatically saved to localStorage per programme/level
- **Server Save**: Click "Save Courses" button to save to server

### Timetable Form
- **5 Time Slots**: Per day/programme/level combination
- **Fields per slot**:
  - Course Code
  - Course Title
  - Time (HH:MM format)
  - Duration (0.5, 1, 1.5, 2, 2.5, or 3 hours)
  - Venue
  - Lecturer Name
- **Auto-save**: Automatically saves to localStorage
- **Immediate Updates**: Changes reflect immediately in the interface

## Data Storage

- **Frontend**: Uses browser localStorage for local persistence (survives page refresh)
- **Backend**: JSON files stored in `/backend/data/`
  - `courses.json`: All course entries organized by programme/level
  - `timetable.json`: All timetable entries organized by programme/level
- **Sync**: Click Save buttons to sync local changes to the server
