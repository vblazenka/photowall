# PhotoWall Migration Plan: Library API → Photos Picker API

## Executive Summary

**Problem**: The Google Photos Library API scopes (`photoslibrary.readonly`) were deprecated and removed on March 31, 2025. As of December 2, 2025, any attempts to use these scopes result in 403 "insufficient authentication scopes" errors.

**Root Cause**: Google has fundamentally changed how third-party apps access user photos. The Library API now only allows access to photos/videos created by the app itself, not the user's entire photo library.

**Solution**: Migrate to the Google Photos Picker API, which provides a secure, user-controlled way to select photos and albums from their entire library.

**Impact**: This requires significant architectural changes to the app, as we can no longer directly list all albums via API. Users must explicitly select albums through a picker interface.

---

## Understanding the Photos Picker API

### Key Differences from Library API

| Feature | Library API (Old) | Picker API (New) |
|---------|-------------------|------------------|
| **Access Model** | Direct API access to all albums/photos | User-initiated selection via picker UI |
| **Scope** | `photoslibrary.readonly` (removed) | `photospicker.mediaitems.readonly` |
| **Album Listing** | `GET /v1/albums` endpoint | User selects albums via UI |
| **Photo Listing** | `POST /v1/mediaItems:search` | User selects photos via UI |
| **User Control** | App has broad access after consent | User explicitly selects each time |
| **Implementation** | REST API calls | JavaScript/Web-based picker |

### Photos Picker API Overview

- **Picker Session**: Opens a Google-hosted UI where users select photos/albums
- **Session API**: Returns media items selected by the user
- **OAuth Scope**: `https://www.googleapis.com/auth/photospicker.mediaitems.readonly`
- **Platform Support**: Web-based (can be embedded in native apps via WebView)

### Documentation Links

- [Photos Picker API Overview](https://developers.google.com/photos/picker/overview)
- [Photos Picker JavaScript API](https://developers.google.com/photos/picker/guides/get-started)
- [Authorization Scopes](https://developers.google.com/photos/overview/authorization)
- [Migration Guide](https://developers.google.com/photos/support/updates)

---

## Architecture Changes

### Current Architecture (Library API)

```
User signs in → App gets access token
↓
App calls /v1/albums → Lists all albums
↓
User selects album → App calls /v1/mediaItems:search
↓
App downloads photos → Sets as wallpaper
```

### New Architecture (Picker API)

```
User signs in → App gets access token with photospicker scope
↓
User clicks "Select Albums" → App opens Picker UI (WebView)
↓
User selects albums in Picker → Picker returns selected album IDs + media items
↓
App stores selection → Downloads photos → Sets as wallpaper
```

### Key Architectural Changes

1. **Replace AlbumsView**: No longer fetch albums via API. Instead, open Picker UI.
2. **WebView Integration**: Need to embed Google Picker in a WebView or browser.
3. **Session Management**: Picker uses session-based API, not direct REST calls.
4. **User Flow Change**: Users must actively select albums each time (can't auto-refresh).
5. **OAuth Scope Update**: Replace `photoslibrary.readonly` with `photospicker.mediaitems.readonly`.

---

## Implementation Plan

### Phase 1: Research & Setup (1-2 days)

#### Task 1.1: Study Photos Picker API
- [ ] Read [Picker API documentation](https://developers.google.com/photos/picker/overview)
- [ ] Understand session creation and media item retrieval
- [ ] Review [JavaScript API reference](https://developers.google.com/photos/picker/guides/get-started)
- [ ] Check if there's a native iOS/macOS SDK or if WebView is required

#### Task 1.2: Explore Implementation Options
- [ ] Option A: Embed Picker in WKWebView within SwiftUI
- [ ] Option B: Open Picker in external browser and handle callback
- [ ] Option C: Use SafariViewController (if available for macOS)
- [ ] Decision: Choose implementation approach

#### Task 1.3: Update Google Cloud Console
- [ ] Remove deprecated `photoslibrary.readonly` scope from OAuth consent screen
- [ ] Add new scope: `https://www.googleapis.com/auth/photospicker.mediaitems.readonly`
- [ ] Update test users if needed
- [ ] Save changes and wait for propagation (may take hours)

---

### Phase 2: OAuth & Authentication (1 day)

#### Task 2.1: Update OAuth Configuration
- [ ] File: `PhotoWall/Managers/AuthManager.swift`
- [ ] Replace scope in `OAuthConfiguration.googlePhotos`:
  ```swift
  scopes: [
      "https://www.googleapis.com/auth/photospicker.mediaitems.readonly",
      "openid",
      "email",
      "profile"
  ]
  ```
- [ ] Update any scope validation logic

#### Task 2.2: Clear Old Credentials
- [ ] Add migration helper to detect and clear old tokens with deprecated scopes
- [ ] Force users to re-authenticate on first launch after update
- [ ] Update `checkExistingAuth()` to handle scope migration

#### Task 2.3: Test Authentication
- [ ] Sign out completely
- [ ] Sign in with new scope
- [ ] Verify console shows `photospicker.mediaitems.readonly` in granted scopes
- [ ] Ensure no 403 errors during auth flow

---

### Phase 3: Picker Integration (2-3 days)

#### Task 3.1: Create Picker Service
- [ ] File: `PhotoWall/Services/PhotosPickerService.swift`
- [ ] Implement session creation: `POST https://photospicker.googleapis.com/v1/sessions`
- [ ] Handle picker configuration (select albums vs photos, multi-select, etc.)
- [ ] Return session ID and picker URL

#### Task 3.2: Implement WebView Picker UI
- [ ] File: `PhotoWall/Views/PickerWebView.swift`
- [ ] Create SwiftUI view with WKWebView
- [ ] Load picker URL from session
- [ ] Handle JavaScript callbacks when user completes selection
- [ ] Extract selected media items from picker response

#### Task 3.3: Update AlbumsView
- [ ] File: `PhotoWall/Views/AlbumsView.swift`
- [ ] Replace "Fetch Albums" logic with "Open Picker" button
- [ ] Launch PickerWebView when user taps button
- [ ] Process selected albums from picker
- [ ] Display selected albums in UI (cached from picker response)

#### Task 3.4: Session Media Items API
- [ ] Implement `GET https://photospicker.googleapis.com/v1/{session.mediaItemsSet.id}/mediaItems`
- [ ] Parse media items from picker session
- [ ] Map to existing `Photo` model (or create new model)
- [ ] Handle pagination if needed

---

### Phase 4: PhotosManager Refactor (2 days)

#### Task 4.1: Remove Deprecated API Calls
- [ ] File: `PhotoWall/Managers/PhotosManager.swift`
- [ ] Delete `fetchAlbums()` method (uses deprecated `/v1/albums` endpoint)
- [ ] Delete `fetchPhotos(albumId:)` method (uses deprecated `/v1/mediaItems:search`)
- [ ] Remove debug logging added during troubleshooting

#### Task 4.2: Implement Picker-Based Photo Fetching
- [ ] Add `func processPickerSelection(sessionId: String) async throws -> [Album]`
- [ ] Fetch media items from picker session
- [ ] Group media items by album (if picker returns album info)
- [ ] Cache results locally for rotation

#### Task 4.3: Update Photo Download
- [ ] Keep existing `downloadPhoto(photo:quality:)` method
- [ ] Verify photo URLs from picker are compatible with existing download logic
- [ ] Test that `baseUrl` + parameters still works for downloads

#### Task 4.4: Error Handling
- [ ] Add new error cases for picker-specific errors
- [ ] Handle session expiration
- [ ] Handle user cancellation
- [ ] Update error messages to reflect new flow

---

### Phase 5: UI/UX Updates (1-2 days)

#### Task 5.1: Update MainView Flow
- [ ] File: `PhotoWall/Views/MainView.swift`
- [ ] Update navigation to reflect new album selection flow
- [ ] Add "Select Albums" button prominently
- [ ] Show currently selected albums from cache

#### Task 5.2: Update PhotosView
- [ ] File: `PhotoWall/Views/PhotosView.swift`
- [ ] Display photos from picker selection (cached)
- [ ] Add "Select More Photos" button to re-open picker
- [ ] Handle empty selection state

#### Task 5.3: Settings Updates
- [ ] File: `PhotoWall/Views/SettingsView.swift`
- [ ] Add option to "Re-select Albums" (clears cache, opens picker)
- [ ] Update help text to explain picker-based selection
- [ ] Add link to migration documentation

#### Task 5.4: Onboarding/Migration Notice
- [ ] Create new view: `PhotoWall/Views/MigrationNoticeView.swift`
- [ ] Show one-time notice explaining the change to users
- [ ] Explain that they need to re-select albums
- [ ] Dismiss after user acknowledges

---

### Phase 6: Data Persistence (1 day)

#### Task 6.1: Update Models
- [ ] File: `PhotoWall/Models/Models.swift`
- [ ] Update `Album` model to store picker session data if needed
- [ ] Add `PickerSession` model for session info
- [ ] Update `Photo` model if picker returns different metadata

#### Task 6.2: Cache Picker Selections
- [ ] Store selected albums/photos locally
- [ ] Persist picker session ID for re-fetching
- [ ] Implement cache invalidation strategy
- [ ] Handle session expiration (may need to re-select)

#### Task 6.3: Update SettingsManager
- [ ] File: `PhotoWall/Managers/SettingsManager.swift`
- [ ] Add methods to store/retrieve picker selections
- [ ] Update UserDefaults keys if needed
- [ ] Handle migration from old album selection format

---

### Phase 7: WallpaperManager Updates (1 day)

#### Task 7.1: Verify Compatibility
- [ ] File: `PhotoWall/Managers/WallpaperManager.swift`
- [ ] Test that photos from picker work with existing rotation logic
- [ ] Verify downloads and caching still work
- [ ] Check multi-display support

#### Task 7.2: Handle Empty Selection
- [ ] Add logic to handle case where no albums are selected
- [ ] Show prompt to select albums
- [ ] Disable rotation until albums are selected

#### Task 7.3: Refresh Strategy
- [ ] Since picker requires user interaction, can't auto-refresh albums
- [ ] Add manual "Refresh Albums" option
- [ ] Consider showing "last updated" timestamp
- [ ] Notify user if selection is stale

---

### Phase 8: Testing (2 days)

#### Task 8.1: Unit Tests
- [ ] Update `PhotoWallTests/` to reflect new API
- [ ] Mock picker session API responses
- [ ] Test picker selection processing
- [ ] Update property tests for new models

#### Task 8.2: Integration Tests
- [ ] Test full flow: Sign in → Select albums → Rotate wallpapers
- [ ] Test re-selection (clearing cache and selecting again)
- [ ] Test empty selection handling
- [ ] Test session expiration handling

#### Task 8.3: Manual Testing
- [ ] Test on multiple macOS versions (13.0+)
- [ ] Test with multiple Google accounts
- [ ] Test with accounts that have many albums
- [ ] Test with accounts that have few/no albums
- [ ] Test picker UI responsiveness

#### Task 8.4: Error Scenario Testing
- [ ] Test network disconnection during picker
- [ ] Test OAuth token expiration
- [ ] Test user canceling picker
- [ ] Test invalid session ID

---

### Phase 9: Documentation & Cleanup (1 day)

#### Task 9.1: Update CLAUDE.md
- [ ] Document new Picker API architecture
- [ ] Update OAuth scope information
- [ ] Add picker integration details
- [ ] Document session management

#### Task 9.2: Update README
- [ ] Add section explaining picker-based selection
- [ ] Update setup instructions for new OAuth scope
- [ ] Add troubleshooting section for picker issues
- [ ] Include screenshots of picker UI

#### Task 9.3: Code Cleanup
- [ ] Remove debug logging
- [ ] Remove deprecated API code
- [ ] Clean up unused models/methods
- [ ] Update code comments

#### Task 9.4: User-Facing Documentation
- [ ] Create simple user guide
- [ ] Explain how to select albums
- [ ] Explain how to refresh selection
- [ ] FAQ for common issues

---

### Phase 10: Deployment (1 day)

#### Task 10.1: Pre-Deployment Checks
- [ ] All tests passing
- [ ] No compiler warnings
- [ ] OAuth consent screen updated in production
- [ ] New scope verified in Google Cloud Console

#### Task 10.2: Build Release
- [ ] Update version number
- [ ] Create release build
- [ ] Test release build thoroughly
- [ ] Archive for distribution

#### Task 10.3: Rollout Plan
- [ ] Beta test with small group (if applicable)
- [ ] Monitor for issues
- [ ] Gradual rollout or full release
- [ ] Prepare rollback plan if needed

#### Task 10.4: Post-Deployment
- [ ] Monitor error logs
- [ ] Collect user feedback
- [ ] Address any critical issues quickly
- [ ] Plan follow-up improvements

---

## Alternative Approaches

### Option 1: Keep Using Library API (Limited)

**Description**: Continue using Library API but only access app-created photos.

**Pros**:
- Minimal code changes
- No picker integration needed

**Cons**:
- ❌ Useless for PhotoWall's purpose (can't access user's photo library)
- ❌ Defeats the entire app concept
- ❌ Not a viable solution

**Verdict**: Not recommended.

---

### Option 2: Wait for Alternative Solution

**Description**: Wait to see if Google provides another API for library access.

**Pros**:
- No immediate work needed
- Might be simpler solution later

**Cons**:
- ❌ App is broken now
- ❌ No indication Google will reverse this decision
- ❌ Users can't use the app

**Verdict**: Not recommended.

---

### Option 3: Pivot to Different Photo Source

**Description**: Use local photo library (macOS Photos app) instead of Google Photos.

**Pros**:
- No Google API dependency
- Full access to local photos
- No authentication needed

**Cons**:
- Completely different use case
- Requires PhotoKit/CoreMedia integration
- May not meet user needs (many users want cloud photos)

**Verdict**: Consider as future feature, but not replacement for Google Photos.

---

## Risk Assessment

### High Risk

| Risk | Impact | Mitigation |
|------|--------|------------|
| Picker API doesn't work on macOS | High | Test early, explore WebView alternatives |
| Google changes Picker API too | High | Stay updated on Google announcements |
| Users don't understand new flow | Medium | Clear onboarding, documentation |

### Medium Risk

| Risk | Impact | Mitigation |
|------|--------|------------|
| Picker sessions expire too quickly | Medium | Implement robust refresh logic |
| WebView performance issues | Medium | Optimize loading, add loading indicators |
| Album metadata lost in picker | Medium | Store additional info locally |

### Low Risk

| Risk | Impact | Mitigation |
|------|--------|------------|
| Migration takes longer than planned | Low | Buffer time in schedule |
| Edge cases in photo URLs | Low | Comprehensive testing |

---

## Success Criteria

### Must Have
- ✅ Users can select albums via picker
- ✅ Selected albums' photos can be downloaded
- ✅ Wallpaper rotation works with picker photos
- ✅ No 403 authentication errors
- ✅ All existing features work (rotation, pause, settings)

### Should Have
- ✅ Smooth picker UI experience
- ✅ Clear user guidance for new flow
- ✅ Cached selections persist across app restarts
- ✅ Manual refresh option for stale selections

### Nice to Have
- 🎯 Automatic session refresh when possible
- 🎯 Better album organization/grouping
- 🎯 Preview of albums before rotation
- 🎯 Import/export album selections

---

## Timeline Estimate

| Phase | Duration | Dependencies |
|-------|----------|--------------|
| Phase 1: Research & Setup | 1-2 days | None |
| Phase 2: OAuth & Authentication | 1 day | Phase 1 |
| Phase 3: Picker Integration | 2-3 days | Phase 2 |
| Phase 4: PhotosManager Refactor | 2 days | Phase 3 |
| Phase 5: UI/UX Updates | 1-2 days | Phase 4 |
| Phase 6: Data Persistence | 1 day | Phase 5 |
| Phase 7: WallpaperManager Updates | 1 day | Phase 6 |
| Phase 8: Testing | 2 days | Phase 7 |
| Phase 9: Documentation & Cleanup | 1 day | Phase 8 |
| Phase 10: Deployment | 1 day | Phase 9 |

**Total Estimated Time**: 12-16 days (2.5-3.5 weeks)

---

## Resources

### Google Documentation
- [Photos Picker API Overview](https://developers.google.com/photos/picker/overview)
- [Picker JavaScript API](https://developers.google.com/photos/picker/guides/get-started)
- [Authorization Scopes](https://developers.google.com/photos/overview/authorization)
- [Migration Updates](https://developers.google.com/photos/support/updates)
- [Release Notes](https://developers.google.com/photos/support/release-notes)

### Community Resources
- [Stack Overflow: Photos.readonly permission fails](https://stackoverflow.com/questions/79644098/google-photos-library-api-photos-readonly-permission-granted-but-requests-fai)
- [Hacker News Discussion](https://news.ycombinator.com/item?id=41604241)
- [rclone Issue #8567](https://github.com/rclone/rclone/issues/8567)

### Apple Documentation
- [WKWebView](https://developer.apple.com/documentation/webkit/wkwebview)
- [SwiftUI WebView Integration](https://developer.apple.com/tutorials/swiftui)

---

## Next Steps

1. **Read this plan thoroughly**
2. **Review Photos Picker API documentation**
3. **Decide on implementation approach** (WebView vs external browser)
4. **Create feature branch**: `git checkout -b feature/picker-api-migration`
5. **Start with Phase 1: Research & Setup**
6. **Update this plan as you learn more**

---

## Questions to Answer During Research

- [ ] Does Photos Picker API work in WKWebView on macOS?
- [ ] Can we embed the picker UI seamlessly in our app?
- [ ] How long do picker sessions last?
- [ ] Can we programmatically refresh sessions?
- [ ] Does the picker return album metadata (title, cover photo)?
- [ ] What's the maximum number of items that can be selected?
- [ ] Are there rate limits on picker session creation?
- [ ] Can users re-select the same albums to refresh?

---

## Notes

- This migration is **mandatory** - the app cannot function without it
- The change is **permanent** - Google is not reverting this decision
- The new flow is **more user-controlled** - aligns with Google's privacy goals
- Plan for **user education** - this is a significant UX change
- Consider this a **major version update** (e.g., 2.0.0)

---

*Last Updated: December 2, 2025*
*Status: Draft - Ready for Implementation*
