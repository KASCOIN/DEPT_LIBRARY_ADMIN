# Inactivity Timeout Feature

## Overview
The student portal now includes an automatic session timeout feature that logs out students after a period of inactivity for security purposes.

## Configuration

### Timeout Settings (in `frontend/student/js/session.js`)
- **INACTIVITY_TIMEOUT**: 15 minutes (900,000 milliseconds)
- **WARNING_TIME**: 1 minute (60,000 milliseconds)

To change these values, edit the constants at the top of the inactivity timeout section:

```javascript
const INACTIVITY_TIMEOUT = 15 * 60 * 1000; // Change the 15 to desired minutes
const WARNING_TIME = 1 * 60 * 1000; // Change the 1 to desired warning minutes
```

## How It Works

### Activity Detection
The system monitors the following user activities and **resets the timeout** when detected:
- Mouse movements
- Mouse clicks
- Keyboard input
- Page scrolling
- Touch events

### Timeout Flow

1. **Student logs in** → Inactivity timer starts
2. **Student is active** → Timer resets with each activity
3. **14 minutes of inactivity** → Warning modal appears
   - Countdown timer shows remaining time (60 seconds)
   - Two buttons: "Continue Working" and "Logout Now"
4. **Student ignores warning for 1 minute** → Automatic logout
   - "Session Expired" message shown
   - Redirected to login page after 3 seconds

### Student Actions

#### Continue Working
- Clicking "Continue Working" button resets the timer
- Automatically triggered by any page activity (clicking, typing, scrolling, etc.)
- Modal closes and countdown resets

#### Manual Logout
- Clicking "Logout Now" button performs immediate logout
- User is redirected to login page

## Visual Design

### Warning Modal Features
- **Prominent header** with ⏱️ icon and orange/red gradient
- **Large countdown timer** showing remaining seconds in red
- **Clear action buttons**:
  - Green "✓ Continue Working" button
  - Gray "🚪 Logout Now" button
- **Responsive design** works on all screen sizes
- **Backdrop blur** effect for focus

## Technical Implementation

### Files Modified

1. **frontend/student/js/session.js**
   - Added inactivity timeout management
   - Activity listener setup
   - Warning and logout functions

2. **frontend/student/student-main.html**
   - Added inactivity warning modal HTML

3. **frontend/student/css/student-dashboard.css**
   - Added comprehensive modal styling
   - Animation effects

## Security Benefits

✓ Prevents unauthorized access from unattended computers
✓ Automatic cleanup of abandoned sessions
✓ Grace period with visible warning before logout
✓ User-friendly with clear messaging
✓ Respects active usage (doesn't interrupt working sessions)

## User Experience

- **Non-intrusive**: Warning appears only when needed
- **Informative**: Clear countdown and messaging
- **Responsive**: Multiple ways to prevent logout (any activity or clicking button)
- **Graceful**: Clear redirect to login after timeout

## Testing

To test the feature:

1. Log in as a student
2. Don't perform any activity for 14 minutes
3. Warning modal appears with 60-second countdown
4. Verify options:
   - Click "Continue Working" → timer resets
   - Perform any activity (click, type, scroll) → modal closes, timer resets
   - Wait for countdown to zero → automatic logout and redirect

## Future Enhancements

- Make timeout period configurable per user role/institution
- Add audit logging for timeout events
- Allow administrators to configure timeout in settings
- Show last activity time in profile
- Add "remember me" option to extend timeout automatically
