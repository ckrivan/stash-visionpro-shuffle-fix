# ✅ Connection successful
🎬 Audio cleanup pause complete, proceeding with player setup
🎬 Initial streaming format: Direct
🎬 Creating stream request for scene 815, useHLS: false
📡 GraphQL Response Status: 200
📡 GraphQL Response: {"data":{"findScene":{"id":"815","title":"","details":"","url":null,"date":null,"rating100":null,"organized":false,"o_counter":0,"paths":{"screenshot":"http://192.168.86.100:9999/scene/815/screenshot?t=1723490951","preview":"http://192.168.86.100:9999/scene/815/preview","stream":"http://192.168.86.100:9999/scene/815/stream?apikey=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOiJjayIsInN1YiI6IkFQSUtleSIsImlhdCI6MTczMTgwOTM2Mn0.7AOyZqTzyDsSnuDx__RBhuIIkoPg2btebToAlpK1zXo","webp":"http://192.168.86.100:9999/scene/815/webp","vtt":"http://192.168.86.100:9999/scene/9a6da7b8d0b06712_thumbs.vtt","sprite":"http://192.168.86.100:9999/scene/9a6da7b8d0b06712_sprite.jpg","funscript":"http://192.168.86.100:9999/scene/815/funscript","interactive_heatmap":"http://192.168.86.100:9999/scene/815/interactive_heatmap"},"files":[{"size":159550238,"duration":1693.61,"video_codec":"hevc","width":576,"height":320}],"performers":[],"tags":[],"studio":null,"stash_ids":[],"created_at":"2024-08-12T09:00:19-04:00","updated_at":"2024-08-12T15:29:11-04:00"}}}
🎬 Scene 815 is VR content: false
🎬 Using direct streaming for this request
🎬 Using direct streaming
🎬 Created stream URL: http://192.168.86.100:9999/scene/815/stream?apikey=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOiJjayIsInN1YiI6IkFQSUtleSIsImlhdCI6MTczMTgwOTM2Mn0.7AOyZqTzyDsSnuDx__RBhuIIkoPg2btebToAlpK1zXo&t=1215
🔑 Authentication headers set: ApiKey and Bearer token
🎬 Using direct streaming URL: http://192.168.86.100:9999/scene/815/stream?apikey=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOiJjayIsInN1YiI6IkFQSUtleSIsImlhdCI6MTczMTgwOTM2Mn0.7AOyZqTzyDsSnuDx__RBhuIIkoPg2btebToAlpK1zXo&t=1215
⚠️ Asset preloading failed: Cannot Open
📝 Registering preview player in global manager
⚠️ Playback not likely to keep up - buffer issues
📊 Stall counter: 1/3
⚠️ Playback buffer empty
✅ Player setup complete
🎬 Creating video player view
🎬 Setting up player layer
📏 PlayerContainerView size changed from (0.0, 0.0) to (1280.0, 720.0)
🎬 Player layer configuration:
- Frame: (0.0, 0.0, 1280.0, 720.0)
- Video gravity: AVLayerVideoGravity(_rawValue: AVLayerVideoGravityResizeAspect)
- Draws asynchronously: true
⏳ Player is waiting to play
⏳ Player is waiting to play
❌ Mounted VTT directory not found or couldn't be read
❌ Player item failed: Optional(Error Domain=AVFoundationErrorDomain Code=-11828 "Cannot Open" UserInfo={NSLocalizedFailureReason=This media format is not supported., NSLocalizedDescription=Cannot Open, NSUnderlyingError=0x600001d07e40 {Error Domain=NSOSStatusErrorDomain Code=-12847 "(null)"}})
❌ Error domain: AVFoundationErrorDomain
❌ Error code: -11828
❌ Underlying error: Error Domain=NSOSStatusErrorDomain Code=-12847 "(null)"
🚨 Critical AVFoundation error detected: Cannot Open - initiating immediate fallback
⏳ Player is waiting to play
🚨 Critical playback failure detected - initiating immediate fallback
🔁 Critical failure: Retry attempt 1 of 5 with direct mode
🎬 Setting up player for scene: 815
⚠️ No fallback position found for scene 815
📊 Preserved playback position at 00:00 for fallback
🧹 Performing thorough player cleanup
🧹 Removed all KVO observers
⏸️ Player is paused
🧹 Removed time observer
⏸️ Player is paused
📝 Unregistering preview player from global manager
🧹 Unregistered player from global manager
✅ Audio session explicitly reset
⏹️ Performing safe audio cleanup
✅ Audio session reset successfully
✅ Used global manager for additional audio cleanup
✅ Player cleanup complete
🧹 CRITICAL: Clearing all caches and state data for proper reset
🧹 Reset all cached data for new video (scene ID: 815)
🔄 StashAPI initializing with server: http://192.168.86.100:9999
🎬 Cleaning up player view
🔄 Checking connection status...
🔄 Checking server connection to http://192.168.86.100:9999
📤 Sending connection check request...
🔍 No oshash found in fingerprints for VTT, attempting to fetch it directly
✅ Found oshash fingerprint via API for VTT: 9a6da7b8d0b06712
🔑 Created VTT URL with fetched oshash: http://192.168.86.100:9999/scene/9a6da7b8d0b06712_thumbs.vtt?apikey=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOiJjayIsInN1YiI6IkFQSUtleSIsImlhdCI6MTczMTgwOTM2Mn0.7AOyZqTzyDsSnuDx__RBhuIIkoPg2btebToAlpK1zXo
📡 Server responded with status code: 200
📥 Response: {"data":{"findPerformers":{"count":955,"performers":[{"id":"55","name":"Aaliyah Love"}]}}}...
✅ Server connection successful
📊 Performers data: ["performers": <__NSSingleObjectArrayI 0x600001295700>(
{
    id = 55;
    name = "Aaliyah Love";
}
)
, "count": 955]
🔍 Attempting to load VTT from local or remote: http://192.168.86.100:9999/scene/9a6da7b8d0b06712_thumbs.vtt?apikey=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOiJjayIsInN1YiI6IkFQSUtleSIsImlhdCI6MTczMTgwOTM2Mn0.7AOyZqTzyDsSnuDx__RBhuIIkoPg2btebToAlpK1zXo
🔍 Attempting to parse VTT from URL: http://192.168.86.100:9999/scene/9a6da7b8d0b06712_thumbs.vtt?apikey=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOiJjayIsInN1YiI6IkFQSUtleSIsImlhdCI6MTczMTgwOTM2Mn0.7AOyZqTzyDsSnuDx__RBhuIIkoPg2btebToAlpK1zXo
✅ Connection successful
🌐 VTT HTTP response: 200
🔍 VTT content preview: WEBVTT

00:00:00.000 --> 00:00:20.887
9a6da7b8d0b06712_sprite.jpg#xywh=0,0,160,88

00:00:20.887 --> 00:00:41.775
9a6da7b8d0b06712_sprite.jpg#xywh=160,0,160,88

00:00:41.775 --> 00:01:02.662
9a6da7b8d0...
🔍 Parsing 245 lines from VTT content
🕒 Found time cue: 00:00:00.000 --> 00:00:20.887 (0.0-20.887)
🎯 Found sprite coordinates: 0,0,160,88
🕒 Found time cue: 00:00:20.887 --> 00:00:41.775 (20.887-41.775)
🎯 Found sprite coordinates: 160,0,160,88
🕒 Found time cue: 00:00:41.775 --> 00:01:02.662 (41.775-62.662)
🎯 Found sprite coordinates: 320,0,160,88
🕒 Found time cue: 00:01:02.662 --> 00:01:23.550 (62.662-83.55)
🎯 Found sprite coordinates: 480,0,160,88
🕒 Found time cue: 00:01:23.550 --> 00:01:44.437 (83.55-104.437)
🎯 Found sprite coordinates: 640,0,160,88
🕒 Found time cue: 00:01:44.437 --> 00:02:05.325 (104.437-125.325)
🎯 Found sprite coordinates: 800,0,160,88
🕒 Found time cue: 00:02:05.325 --> 00:02:26.212 (125.325-146.212)
🎯 Found sprite coordinates: 960,0,160,88
🕒 Found time cue: 00:02:26.212 --> 00:02:47.100 (146.212-167.1)
🎯 Found sprite coordinates: 1120,0,160,88
🕒 Found time cue: 00:02:47.100 --> 00:03:07.987 (167.1-187.987)
🎯 Found sprite coordinates: 1280,0,160,88
🕒 Found time cue: 00:03:07.987 --> 00:03:28.875 (187.987-208.875)
🎯 Found sprite coordinates: 0,88,160,88
🕒 Found time cue: 00:03:28.875 --> 00:03:49.763 (208.875-229.763)
🎯 Found sprite coordinates: 160,88,160,88
🕒 Found time cue: 00:03:49.763 --> 00:04:10.650 (229.763-250.65)
🎯 Found sprite coordinates: 320,88,160,88
🕒 Found time cue: 00:04:10.650 --> 00:04:31.538 (250.65-271.538)
🎯 Found sprite coordinates: 480,88,160,88
🕒 Found time cue: 00:04:31.538 --> 00:04:52.425 (271.538-292.425)
🎯 Found sprite coordinates: 640,88,160,88
🕒 Found time cue: 00:04:52.425 --> 00:05:13.313 (292.425-313.313)
🎯 Found sprite coordinates: 800,88,160,88
🕒 Found time cue: 00:05:13.313 --> 00:05:34.200 (313.313-334.2)
🎯 Found sprite coordinates: 960,88,160,88
🕒 Found time cue: 00:05:34.200 --> 00:05:55.088 (334.2-355.088)
🎯 Found sprite coordinates: 1120,88,160,88
🕒 Found time cue: 00:05:55.088 --> 00:06:15.975 (355.088-375.975)
🎯 Found sprite coordinates: 1280,88,160,88
🕒 Found time cue: 00:06:15.975 --> 00:06:36.863 (375.975-396.863)
🎯 Found sprite coordinates: 0,176,160,88
🕒 Found time cue: 00:06:36.863 --> 00:06:57.751 (396.863-417.751)
🎯 Found sprite coordinates: 160,176,160,88
🕒 Found time cue: 00:06:57.751 --> 00:07:18.638 (417.751-438.638)
🎯 Found sprite coordinates: 320,176,160,88
🕒 Found time cue: 00:07:18.638 --> 00:07:39.526 (438.638-459.526)
🎯 Found sprite coordinates: 480,176,160,88
🕒 Found time cue: 00:07:39.526 --> 00:08:00.413 (459.526-480.413)
🎯 Found sprite coordinates: 640,176,160,88
🕒 Found time cue: 00:08:00.413 --> 00:08:21.301 (480.413-501.301)
🎯 Found sprite coordinates: 800,176,160,88
🕒 Found time cue: 00:08:21.301 --> 00:08:42.188 (501.301-522.188)
🎯 Found sprite coordinates: 960,176,160,88
🕒 Found time cue: 00:08:42.188 --> 00:09:03.076 (522.188-543.076)
🎯 Found sprite coordinates: 1120,176,160,88
🕒 Found time cue: 00:09:03.076 --> 00:09:23.963 (543.076-563.963)
🎯 Found sprite coordinates: 1280,176,160,88
🕒 Found time cue: 00:09:23.963 --> 00:09:44.851 (563.963-584.851)
🎯 Found sprite coordinates: 0,264,160,88
🕒 Found time cue: 00:09:44.851 --> 00:10:05.739 (584.851-605.739)
🎯 Found sprite coordinates: 160,264,160,88
🕒 Found time cue: 00:10:05.739 --> 00:10:26.626 (605.739-626.626)
🎯 Found sprite coordinates: 320,264,160,88
🕒 Found time cue: 00:10:26.626 --> 00:10:47.514 (626.626-647.514)
🎯 Found sprite coordinates: 480,264,160,88
🕒 Found time cue: 00:10:47.514 --> 00:11:08.401 (647.514-668.401)
🎯 Found sprite coordinates: 640,264,160,88
🕒 Found time cue: 00:11:08.401 --> 00:11:29.289 (668.401-689.289)
🎯 Found sprite coordinates: 800,264,160,88
🕒 Found time cue: 00:11:29.289 --> 00:11:50.176 (689.289-710.176)
🎯 Found sprite coordinates: 960,264,160,88
🕒 Found time cue: 00:11:50.176 --> 00:12:11.064 (710.176-731.064)
🎯 Found sprite coordinates: 1120,264,160,88
🕒 Found time cue: 00:12:11.064 --> 00:12:31.951 (731.064-751.951)
🎯 Found sprite coordinates: 1280,264,160,88
🕒 Found time cue: 00:12:31.951 --> 00:12:52.839 (751.951-772.8389999999999)
🎯 Found sprite coordinates: 0,352,160,88
🕒 Found time cue: 00:12:52.839 --> 00:13:13.727 (772.8389999999999-793.727)
🎯 Found sprite coordinates: 160,352,160,88
🕒 Found time cue: 00:13:13.727 --> 00:13:34.614 (793.727-814.614)
🎯 Found sprite coordinates: 320,352,160,88
🕒 Found time cue: 00:13:34.614 --> 00:13:55.502 (814.614-835.502)
🎯 Found sprite coordinates: 480,352,160,88
🕒 Found time cue: 00:13:55.502 --> 00:14:16.389 (835.502-856.389)
🎯 Found sprite coordinates: 640,352,160,88
🕒 Found time cue: 00:14:16.389 --> 00:14:37.277 (856.389-877.277)
🎯 Found sprite coordinates: 800,352,160,88
🕒 Found time cue: 00:14:37.277 --> 00:14:58.164 (877.277-898.164)
🎯 Found sprite coordinates: 960,352,160,88
🕒 Found time cue: 00:14:58.164 --> 00:15:19.052 (898.164-919.052)
🎯 Found sprite coordinates: 1120,352,160,88
🕒 Found time cue: 00:15:19.052 --> 00:15:39.939 (919.052-939.939)
🎯 Found sprite coordinates: 1280,352,160,88
🕒 Found time cue: 00:15:39.939 --> 00:16:00.827 (939.939-960.827)
🎯 Found sprite coordinates: 0,440,160,88
🕒 Found time cue: 00:16:00.827 --> 00:16:21.715 (960.827-981.715)
🎯 Found sprite coordinates: 160,440,160,88
🕒 Found time cue: 00:16:21.715 --> 00:16:42.602 (981.715-1002.602)
🎯 Found sprite coordinates: 320,440,160,88
🕒 Found time cue: 00:16:42.602 --> 00:17:03.490 (1002.602-1023.49)
🎯 Found sprite coordinates: 480,440,160,88
🕒 Found time cue: 00:17:03.490 --> 00:17:24.377 (1023.49-1044.377)
🎯 Found sprite coordinates: 640,440,160,88
🕒 Found time cue: 00:17:24.377 --> 00:17:45.265 (1044.377-1065.265)
🎯 Found sprite coordinates: 800,440,160,88
🕒 Found time cue: 00:17:45.265 --> 00:18:06.152 (1065.265-1086.152)
🎯 Found sprite coordinates: 960,440,160,88
🕒 Found time cue: 00:18:06.152 --> 00:18:27.040 (1086.152-1107.04)
🎯 Found sprite coordinates: 1120,440,160,88
🕒 Found time cue: 00:18:27.040 --> 00:18:47.927 (1107.04-1127.927)
🎯 Found sprite coordinates: 1280,440,160,88
🕒 Found time cue: 00:18:47.927 --> 00:19:08.815 (1127.927-1148.815)
🎯 Found sprite coordinates: 0,528,160,88
🕒 Found time cue: 00:19:08.815 --> 00:19:29.703 (1148.815-1169.703)
🎯 Found sprite coordinates: 160,528,160,88
🕒 Found time cue: 00:19:29.703 --> 00:19:50.590 (1169.703-1190.59)
🎯 Found sprite coordinates: 320,528,160,88
🕒 Found time cue: 00:19:50.590 --> 00:20:11.478 (1190.59-1211.478)
🎯 Found sprite coordinates: 480,528,160,88
🕒 Found time cue: 00:20:11.478 --> 00:20:32.365 (1211.478-1232.365)
🎯 Found sprite coordinates: 640,528,160,88
🕒 Found time cue: 00:20:32.365 --> 00:20:53.253 (1232.365-1253.253)
🎯 Found sprite coordinates: 800,528,160,88
🕒 Found time cue: 00:20:53.253 --> 00:21:14.140 (1253.253-1274.14)
🎯 Found sprite coordinates: 960,528,160,88
🕒 Found time cue: 00:21:14.140 --> 00:21:35.028 (1274.14-1295.028)
🎯 Found sprite coordinates: 1120,528,160,88
🕒 Found time cue: 00:21:35.028 --> 00:21:55.915 (1295.028-1315.915)
🎯 Found sprite coordinates: 1280,528,160,88
🕒 Found time cue: 00:21:55.915 --> 00:22:16.803 (1315.915-1336.803)
🎯 Found sprite coordinates: 0,616,160,88
🕒 Found time cue: 00:22:16.803 --> 00:22:37.691 (1336.803-1357.691)
🎯 Found sprite coordinates: 160,616,160,88
🕒 Found time cue: 00:22:37.691 --> 00:22:58.578 (1357.691-1378.578)
🎯 Found sprite coordinates: 320,616,160,88
🕒 Found time cue: 00:22:58.578 --> 00:23:19.466 (1378.578-1399.466)
🎯 Found sprite coordinates: 480,616,160,88
🕒 Found time cue: 00:23:19.466 --> 00:23:40.353 (1399.466-1420.353)
🎯 Found sprite coordinates: 640,616,160,88
🕒 Found time cue: 00:23:40.353 --> 00:24:01.241 (1420.353-1441.241)
🎯 Found sprite coordinates: 800,616,160,88
🕒 Found time cue: 00:24:01.241 --> 00:24:22.128 (1441.241-1462.128)
🎯 Found sprite coordinates: 960,616,160,88
🕒 Found time cue: 00:24:22.128 --> 00:24:43.016 (1462.128-1483.016)
🎯 Found sprite coordinates: 1120,616,160,88
🕒 Found time cue: 00:24:43.016 --> 00:25:03.903 (1483.016-1503.903)
🎯 Found sprite coordinates: 1280,616,160,88
🕒 Found time cue: 00:25:03.903 --> 00:25:24.791 (1503.903-1524.791)
🎯 Found sprite coordinates: 0,704,160,88
🕒 Found time cue: 00:25:24.791 --> 00:25:45.679 (1524.791-1545.679)
🎯 Found sprite coordinates: 160,704,160,88
🕒 Found time cue: 00:25:45.679 --> 00:26:06.566 (1545.679-1566.566)
🎯 Found sprite coordinates: 320,704,160,88
🕒 Found time cue: 00:26:06.566 --> 00:26:27.454 (1566.566-1587.454)
🎯 Found sprite coordinates: 480,704,160,88
🕒 Found time cue: 00:26:27.454 --> 00:26:48.341 (1587.454-1608.341)
🎯 Found sprite coordinates: 640,704,160,88
🕒 Found time cue: 00:26:48.341 --> 00:27:09.229 (1608.341-1629.229)
🎯 Found sprite coordinates: 800,704,160,88
🕒 Found time cue: 00:27:09.229 --> 00:27:30.116 (1629.229-1650.116)
🎯 Found sprite coordinates: 960,704,160,88
🕒 Found time cue: 00:27:30.116 --> 00:27:51.004 (1650.116-1671.004)
🎯 Found sprite coordinates: 1120,704,160,88
🕒 Found time cue: 00:27:51.004 --> 00:28:11.891 (1671.004-1691.891)
🎯 Found sprite coordinates: 1280,704,160,88
✅ Parsed 81 thumbnail entries from VTT content
✅ Loaded 81 VTT entries from mounted location or server
🔍 No oshash found in fingerprints, attempting to fetch it directly
✅ Found oshash fingerprint via API: 9a6da7b8d0b06712
🔑 Created sprite URL with fetched oshash: http://192.168.86.100:9999/scene/9a6da7b8d0b06712_sprite.jpg?apikey=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOiJjayIsInN1YiI6IkFQSUtleSIsImlhdCI6MTczMTgwOTM2Mn0.7AOyZqTzyDsSnuDx__RBhuIIkoPg2btebToAlpK1zXo
🔍 Attempting to load sprite sheet from local or remote: http://192.168.86.100:9999/scene/9a6da7b8d0b06712_sprite.jpg?apikey=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOiJjayIsInN1YiI6IkFQSUtleSIsImlhdCI6MTczMTgwOTM2Mn0.7AOyZqTzyDsSnuDx__RBhuIIkoPg2btebToAlpK1zXo
🔍 Loading sprite from remote URL
✅ Audio cleanup complete
✅ Loaded sprite sheet: 1440.0x792.0
🎬 Audio cleanup pause complete, proceeding with player setup
🔁 Auto-fallback: Attempt #2 of 5 with direct streaming
🎬 Initial streaming format: Direct
🎬 Creating stream request for scene 815, useHLS: false
📡 GraphQL Response Status: 200
📡 GraphQL Response: {"data":{"findScene":{"id":"815","title":"","details":"","url":null,"date":null,"rating100":null,"organized":false,"o_counter":0,"paths":{"screenshot":"http://192.168.86.100:9999/scene/815/screenshot?t=1723490951","preview":"http://192.168.86.100:9999/scene/815/preview","stream":"http://192.168.86.100:9999/scene/815/stream?apikey=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOiJjayIsInN1YiI6IkFQSUtleSIsImlhdCI6MTczMTgwOTM2Mn0.7AOyZqTzyDsSnuDx__RBhuIIkoPg2btebToAlpK1zXo","webp":"http://192.168.86.100:9999/scene/815/webp","vtt":"http://192.168.86.100:9999/scene/9a6da7b8d0b06712_thumbs.vtt","sprite":"http://192.168.86.100:9999/scene/9a6da7b8d0b06712_sprite.jpg","funscript":"http://192.168.86.100:9999/scene/815/funscript","interactive_heatmap":"http://192.168.86.100:9999/scene/815/interactive_heatmap"},"files":[{"size":159550238,"duration":1693.61,"video_codec":"hevc","width":576,"height":320}],"performers":[],"tags":[],"studio":null,"stash_ids":[],"created_at":"2024-08-12T09:00:19-04:00","updated_at":"2024-08-12T15:29:11-04:00"}}}
🎬 Scene 815 is VR content: false
🎬 Using direct streaming for this request
🎬 Using direct streaming
🎬 Created stream URL: http://192.168.86.100:9999/scene/815/stream?apikey=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOiJjayIsInN1YiI6IkFQSUtleSIsImlhdCI6MTczMTgwOTM2Mn0.7AOyZqTzyDsSnuDx__RBhuIIkoPg2btebToAlpK1zXo&t=1215
🔑 Authentication headers set: ApiKey and Bearer token
🎬 Using direct streaming URL: http://192.168.86.100:9999/scene/815/stream?apikey=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOiJjayIsInN1YiI6IkFQSUtleSIsImlhdCI6MTczMTgwOTM2Mn0.7AOyZqTzyDsSnuDx__RBhuIIkoPg2btebToAlpK1zXo&t=1215
⚠️ Asset preloading failed: Cannot Open
📝 Registering preview player in global manager
⚠️ Playback not likely to keep up - buffer issues
📊 Stall counter: 2/3
⚠️ Playback buffer empty
✅ Player setup complete
🎬 Creating video player view
🎬 Setting up player layer
📏 PlayerContainerView size changed from (0.0, 0.0) to (1280.0, 720.0)
🎬 Player layer configuration:
- Frame: (0.0, 0.0, 1280.0, 720.0)
- Video gravity: AVLayerVideoGravity(_rawValue: AVLayerVideoGravityResizeAspect)
- Draws asynchronously: true
⏳ Player is waiting to play
⏳ Player is waiting to play
❌ Mounted VTT directory not found or couldn't be read
❌ Player item failed: Optional(Error Domain=AVFoundationErrorDomain Code=-11828 "Cannot Open" UserInfo={NSLocalizedFailureReason=This media format is not supported., NSLocalizedDescription=Cannot Open, NSUnderlyingError=0x600001dde790 {Error Domain=NSOSStatusErrorDomain Code=-12847 "(null)"}})
❌ Error domain: AVFoundationErrorDomain
❌ Error code: -11828
❌ Underlying error: Error Domain=NSOSStatusErrorDomain Code=-12847 "(null)"
🚨 Critical AVFoundation error detected: Cannot Open - initiating immediate fallback
⏳ Player is waiting to play
🚨 Critical playback failure detected - initiating immediate fallback
🔁 Critical failure: Retry attempt 2 of 5 with direct mode
🎬 Setting up player for scene: 815
⚠️ No fallback position found for scene 815
📊 Preserved playback position at 00:00 for fallback
🧹 Performing thorough player cleanup
🧹 Removed all KVO observers
⏸️ Player is paused
🧹 Removed time observer
⏸️ Player is paused
📝 Unregistering preview player from global manager
🧹 Unregistered player from global manager
✅ Audio session explicitly reset
⏹️ Performing safe audio cleanup
✅ Audio session reset successfully
✅ Used global manager for additional audio cleanup
✅ Player cleanup complete
🧹 CRITICAL: Clearing all caches and state data for proper reset
🧹 Reset all cached data for new video (scene ID: 815)
🔄 StashAPI initializing with server: http://192.168.86.100:9999
🎬 Cleaning up player view
🔄 Checking connection status...
🔄 Checking server connection to http://192.168.86.100:9999
📤 Sending connection check request...
🔍 No oshash found in fingerprints, attempting to fetch it directly
📡 Server responded with status code: 200
📥 Response: {"data":{"findPerformers":{"count":955,"performers":[{"id":"55","name":"Aaliyah Love"}]}}}...
✅ Server connection successful
📊 Performers data: ["performers": <__NSSingleObjectArrayI 0x6000012e9390>(
{
    id = 55;
    name = "Aaliyah Love";
}
)
, "count": 955]
✅ Connection successful
✅ Found oshash fingerprint via API: 9a6da7b8d0b06712
🔑 Created sprite URL with fetched oshash: http://192.168.86.100:9999/scene/9a6da7b8d0b06712_sprite.jpg?apikey=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOiJjayIsInN1YiI6IkFQSUtleSIsImlhdCI6MTczMTgwOTM2Mn0.7AOyZqTzyDsSnuDx__RBhuIIkoPg2btebToAlpK1zXo
🔍 Attempting to load sprite sheet from local or remote: http://192.168.86.100:9999/scene/9a6da7b8d0b06712_sprite.jpg?apikey=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOiJjayIsInN1YiI6IkFQSUtleSIsImlhdCI6MTczMTgwOTM2Mn0.7AOyZqTzyDsSnuDx__RBhuIIkoPg2btebToAlpK1zXo
🔍 Loading sprite from remote URL
✅ Loaded sprite sheet: 1440.0x792.0
🔍 5-second playback check: time=nan, playing=no
✅ Audio cleanup complete
🎬 Position check after setup: current=0.0, target=1215.2624208441675
⚠️ Position mismatch detected! Forcing seek to target position
🎭 Updated scene reference to: 
🎭 New scene has no performers
🎬 Audio cleanup pause complete, proceeding with player setup
🔁 Auto-fallback: Attempt #3 of 5 with direct streaming
🎬 Initial streaming format: Direct
🎬 Creating stream request for scene 815, useHLS: false
📡 GraphQL Response Status: 200
📡 GraphQL Response: {"data":{"findScene":{"id":"815","title":"","details":"","url":null,"date":null,"rating100":null,"organized":false,"o_counter":0,"paths":{"screenshot":"http://192.168.86.100:9999/scene/815/screenshot?t=1723490951","preview":"http://192.168.86.100:9999/scene/815/preview","stream":"http://192.168.86.100:9999/scene/815/stream?apikey=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOiJjayIsInN1YiI6IkFQSUtleSIsImlhdCI6MTczMTgwOTM2Mn0.7AOyZqTzyDsSnuDx__RBhuIIkoPg2btebToAlpK1zXo","webp":"http://192.168.86.100:9999/scene/815/webp","vtt":"http://192.168.86.100:9999/scene/9a6da7b8d0b06712_thumbs.vtt","sprite":"http://192.168.86.100:9999/scene/9a6da7b8d0b06712_sprite.jpg","funscript":"http://192.168.86.100:9999/scene/815/funscript","interactive_heatmap":"http://192.168.86.100:9999/scene/815/interactive_heatmap"},"files":[{"size":159550238,"duration":1693.61,"video_codec":"hevc","width":576,"height":320}],"performers":[],"tags":[],"studio":null,"stash_ids":[],"created_at":"2024-08-12T09:00:19-04:00","updated_at":"2024-08-12T15:29:11-04:00"}}}
🎬 Scene 815 is VR content: false
🎬 Using direct streaming for this request
🎬 Using direct streaming
🎬 Created stream URL: http://192.168.86.100:9999/scene/815/stream?apikey=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOiJjayIsInN1YiI6IkFQSUtleSIsImlhdCI6MTczMTgwOTM2Mn0.7AOyZqTzyDsSnuDx__RBhuIIkoPg2btebToAlpK1zXo&t=0
🔑 Authentication headers set: ApiKey and Bearer token
🎬 Using direct streaming URL: http://192.168.86.100:9999/scene/815/stream?apikey=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOiJjayIsInN1YiI6IkFQSUtleSIsImlhdCI6MTczMTgwOTM2Mn0.7AOyZqTzyDsSnuDx__RBhuIIkoPg2btebToAlpK1zXo&t=0
⚠️ Asset preloading failed: Cannot Open
📝 Registering preview player in global manager
⚠️ Playback not likely to keep up - buffer issues
📊 Stall counter: 3/3
⚠️ Multiple consecutive stalls detected in direct playback mode
⚠️ Playback buffer empty
✅ Player setup complete
🎬 Creating video player view
🎬 Setting up player layer
📏 PlayerContainerView size changed from (0.0, 0.0) to (1280.0, 720.0)
🎬 Player layer configuration:
- Frame: (0.0, 0.0, 1280.0, 720.0)
- Video gravity: AVLayerVideoGravity(_rawValue: AVLayerVideoGravityResizeAspect)
- Draws asynchronously: true
⏳ Player is waiting to play
⏳ Player is waiting to play
❌ Mounted VTT directory not found or couldn't be read
❌ Player item failed: Optional(Error Domain=AVFoundationErrorDomain Code=-11828 "Cannot Open" UserInfo={NSLocalizedFailureReason=This media format is not supported., NSLocalizedDescription=Cannot Open, NSUnderlyingError=0x600000209cb0 {Error Domain=NSOSStatusErrorDomain Code=-12847 "(null)"}})
❌ Error domain: AVFoundationErrorDomain
❌ Error code: -11828
❌ Underlying error: Error Domain=NSOSStatusErrorDomain Code=-12847 "(null)"
🚨 Critical AVFoundation error detected: Cannot Open - initiating immediate fallback
⏳ Player is waiting to play
🚨 Critical playback failure detected - initiating immediate fallback
🔁 Critical failure: Retry attempt 3 of 5 with direct mode
🎬 Setting up player for scene: 815
⚠️ No fallback position found for scene 815
📊 Preserved playback position at 00:00 for fallback
🧹 Performing thorough player cleanup
🧹 Removed all KVO observers
⏸️ Player is paused
🧹 Removed time observer
⏸️ Player is paused
📝 Unregistering preview player from global manager
🧹 Unregistered player from global manager
✅ Audio session explicitly reset
⏹️ Performing safe audio cleanup
✅ Audio session reset successfully
✅ Used global manager for additional audio cleanup
✅ Player cleanup complete
🧹 CRITICAL: Clearing all caches and state data for proper reset
🧹 Reset all cached data for new video (scene ID: 815)
🔄 StashAPI initializing with server: http://192.168.86.100:9999
🎬 Cleaning up player view
🔍 No oshash found in fingerprints for VTT, attempting to fetch it directly
🔄 Checking connection status...
🔄 Checking server connection to http://192.168.86.100:9999
📤 Sending connection check request...
📡 Server responded with status code: 200
📥 Response: {"data":{"findPerformers":{"count":955,"performers":[{"id":"55","name":"Aaliyah Love"}]}}}...
✅ Server connection successful
📊 Performers data: ["performers": <__NSSingleObjectArrayI 0x6000012e9570>(
{
    id = 55;
    name = "Aaliyah Love";
}
)
, "count": 955]
✅ Connection successful
✅ Found oshash fingerprint via API for VTT: 9a6da7b8d0b06712
🔑 Created VTT URL with fetched oshash: http://192.168.86.100:9999/scene/9a6da7b8d0b06712_thumbs.vtt?apikey=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOiJjayIsInN1YiI6IkFQSUtleSIsImlhdCI6MTczMTgwOTM2Mn0.7AOyZqTzyDsSnuDx__RBhuIIkoPg2btebToAlpK1zXo
🔍 Attempting to load VTT from local or remote: http://192.168.86.100:9999/scene/9a6da7b8d0b06712_thumbs.vtt?apikey=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOiJjayIsInN1YiI6IkFQSUtleSIsImlhdCI6MTczMTgwOTM2Mn0.7AOyZqTzyDsSnuDx__RBhuIIkoPg2btebToAlpK1zXo
🔍 Attempting to parse VTT from URL: http://192.168.86.100:9999/scene/9a6da7b8d0b06712_thumbs.vtt?apikey=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOiJjayIsInN1YiI6IkFQSUtleSIsImlhdCI6MTczMTgwOTM2Mn0.7AOyZqTzyDsSnuDx__RBhuIIkoPg2btebToAlpK1zXo
🌐 VTT HTTP response: 200
🔍 VTT content preview: WEBVTT

00:00:00.000 --> 00:00:20.887
9a6da7b8d0b06712_sprite.jpg#xywh=0,0,160,88

00:00:20.887 --> 00:00:41.775
9a6da7b8d0b06712_sprite.jpg#xywh=160,0,160,88

00:00:41.775 --> 00:01:02.662
9a6da7b8d0...
🔍 Parsing 245 lines from VTT content
🕒 Found time cue: 00:00:00.000 --> 00:00:20.887 (0.0-20.887)
🎯 Found sprite coordinates: 0,0,160,88
🕒 Found time cue: 00:00:20.887 --> 00:00:41.775 (20.887-41.775)
🎯 Found sprite coordinates: 160,0,160,88
🕒 Found time cue: 00:00:41.775 --> 00:01:02.662 (41.775-62.662)
🎯 Found sprite coordinates: 320,0,160,88
🕒 Found time cue: 00:01:02.662 --> 00:01:23.550 (62.662-83.55)
🎯 Found sprite coordinates: 480,0,160,88
🕒 Found time cue: 00:01:23.550 --> 00:01:44.437 (83.55-104.437)
🎯 Found sprite coordinates: 640,0,160,88
🕒 Found time cue: 00:01:44.437 --> 00:02:05.325 (104.437-125.325)
🎯 Found sprite coordinates: 800,0,160,88
🕒 Found time cue: 00:02:05.325 --> 00:02:26.212 (125.325-146.212)
🎯 Found sprite coordinates: 960,0,160,88
🕒 Found time cue: 00:02:26.212 --> 00:02:47.100 (146.212-167.1)
🎯 Found sprite coordinates: 1120,0,160,88
🕒 Found time cue: 00:02:47.100 --> 00:03:07.987 (167.1-187.987)
🎯 Found sprite coordinates: 1280,0,160,88
🕒 Found time cue: 00:03:07.987 --> 00:03:28.875 (187.987-208.875)
🎯 Found sprite coordinates: 0,88,160,88
🕒 Found time cue: 00:03:28.875 --> 00:03:49.763 (208.875-229.763)
🎯 Found sprite coordinates: 160,88,160,88
🕒 Found time cue: 00:03:49.763 --> 00:04:10.650 (229.763-250.65)
🎯 Found sprite coordinates: 320,88,160,88
🕒 Found time cue: 00:04:10.650 --> 00:04:31.538 (250.65-271.538)
🎯 Found sprite coordinates: 480,88,160,88
🕒 Found time cue: 00:04:31.538 --> 00:04:52.425 (271.538-292.425)
🎯 Found sprite coordinates: 640,88,160,88
🕒 Found time cue: 00:04:52.425 --> 00:05:13.313 (292.425-313.313)
🎯 Found sprite coordinates: 800,88,160,88
🕒 Found time cue: 00:05:13.313 --> 00:05:34.200 (313.313-334.2)
🎯 Found sprite coordinates: 960,88,160,88
🕒 Found time cue: 00:05:34.200 --> 00:05:55.088 (334.2-355.088)
🎯 Found sprite coordinates: 1120,88,160,88
🕒 Found time cue: 00:05:55.088 --> 00:06:15.975 (355.088-375.975)
🎯 Found sprite coordinates: 1280,88,160,88
🕒 Found time cue: 00:06:15.975 --> 00:06:36.863 (375.975-396.863)
🎯 Found sprite coordinates: 0,176,160,88
🕒 Found time cue: 00:06:36.863 --> 00:06:57.751 (396.863-417.751)
🎯 Found sprite coordinates: 160,176,160,88
🕒 Found time cue: 00:06:57.751 --> 00:07:18.638 (417.751-438.638)
🎯 Found sprite coordinates: 320,176,160,88
🕒 Found time cue: 00:07:18.638 --> 00:07:39.526 (438.638-459.526)
🎯 Found sprite coordinates: 480,176,160,88
🕒 Found time cue: 00:07:39.526 --> 00:08:00.413 (459.526-480.413)
🎯 Found sprite coordinates: 640,176,160,88
🕒 Found time cue: 00:08:00.413 --> 00:08:21.301 (480.413-501.301)
🎯 Found sprite coordinates: 800,176,160,88
🕒 Found time cue: 00:08:21.301 --> 00:08:42.188 (501.301-522.188)
🎯 Found sprite coordinates: 960,176,160,88
🕒 Found time cue: 00:08:42.188 --> 00:09:03.076 (522.188-543.076)
🎯 Found sprite coordinates: 1120,176,160,88
🕒 Found time cue: 00:09:03.076 --> 00:09:23.963 (543.076-563.963)
🎯 Found sprite coordinates: 1280,176,160,88
🕒 Found time cue: 00:09:23.963 --> 00:09:44.851 (563.963-584.851)
🎯 Found sprite coordinates: 0,264,160,88
🕒 Found time cue: 00:09:44.851 --> 00:10:05.739 (584.851-605.739)
🎯 Found sprite coordinates: 160,264,160,88
🕒 Found time cue: 00:10:05.739 --> 00:10:26.626 (605.739-626.626)
🎯 Found sprite coordinates: 320,264,160,88
🕒 Found time cue: 00:10:26.626 --> 00:10:47.514 (626.626-647.514)
🎯 Found sprite coordinates: 480,264,160,88
🕒 Found time cue: 00:10:47.514 --> 00:11:08.401 (647.514-668.401)
🎯 Found sprite coordinates: 640,264,160,88
🕒 Found time cue: 00:11:08.401 --> 00:11:29.289 (668.401-689.289)
🎯 Found sprite coordinates: 800,264,160,88
🕒 Found time cue: 00:11:29.289 --> 00:11:50.176 (689.289-710.176)
🎯 Found sprite coordinates: 960,264,160,88
🕒 Found time cue: 00:11:50.176 --> 00:12:11.064 (710.176-731.064)
🎯 Found sprite coordinates: 1120,264,160,88
🕒 Found time cue: 00:12:11.064 --> 00:12:31.951 (731.064-751.951)
🎯 Found sprite coordinates: 1280,264,160,88
🕒 Found time cue: 00:12:31.951 --> 00:12:52.839 (751.951-772.8389999999999)
🎯 Found sprite coordinates: 0,352,160,88
🕒 Found time cue: 00:12:52.839 --> 00:13:13.727 (772.8389999999999-793.727)
🎯 Found sprite coordinates: 160,352,160,88
🕒 Found time cue: 00:13:13.727 --> 00:13:34.614 (793.727-814.614)
🎯 Found sprite coordinates: 320,352,160,88
🕒 Found time cue: 00:13:34.614 --> 00:13:55.502 (814.614-835.502)
🎯 Found sprite coordinates: 480,352,160,88
🕒 Found time cue: 00:13:55.502 --> 00:14:16.389 (835.502-856.389)
🎯 Found sprite coordinates: 640,352,160,88
🕒 Found time cue: 00:14:16.389 --> 00:14:37.277 (856.389-877.277)
🎯 Found sprite coordinates: 800,352,160,88
🕒 Found time cue: 00:14:37.277 --> 00:14:58.164 (877.277-898.164)
🎯 Found sprite coordinates: 960,352,160,88
🕒 Found time cue: 00:14:58.164 --> 00:15:19.052 (898.164-919.052)
🎯 Found sprite coordinates: 1120,352,160,88
🕒 Found time cue: 00:15:19.052 --> 00:15:39.939 (919.052-939.939)
🎯 Found sprite coordinates: 1280,352,160,88
🕒 Found time cue: 00:15:39.939 --> 00:16:00.827 (939.939-960.827)
🎯 Found sprite coordinates: 0,440,160,88
🕒 Found time cue: 00:16:00.827 --> 00:16:21.715 (960.827-981.715)
🎯 Found sprite coordinates: 160,440,160,88
🕒 Found time cue: 00:16:21.715 --> 00:16:42.602 (981.715-1002.602)
🎯 Found sprite coordinates: 320,440,160,88
🕒 Found time cue: 00:16:42.602 --> 00:17:03.490 (1002.602-1023.49)
🎯 Found sprite coordinates: 480,440,160,88
🕒 Found time cue: 00:17:03.490 --> 00:17:24.377 (1023.49-1044.377)
🎯 Found sprite coordinates: 640,440,160,88
🕒 Found time cue: 00:17:24.377 --> 00:17:45.265 (1044.377-1065.265)
🎯 Found sprite coordinates: 800,440,160,88
🕒 Found time cue: 00:17:45.265 --> 00:18:06.152 (1065.265-1086.152)
🎯 Found sprite coordinates: 960,440,160,88
🕒 Found time cue: 00:18:06.152 --> 00:18:27.040 (1086.152-1107.04)
🎯 Found sprite coordinates: 1120,440,160,88
🕒 Found time cue: 00:18:27.040 --> 00:18:47.927 (1107.04-1127.927)
🎯 Found sprite coordinates: 1280,440,160,88
🕒 Found time cue: 00:18:47.927 --> 00:19:08.815 (1127.927-1148.815)
🎯 Found sprite coordinates: 0,528,160,88
🕒 Found time cue: 00:19:08.815 --> 00:19:29.703 (1148.815-1169.703)
🎯 Found sprite coordinates: 160,528,160,88
🕒 Found time cue: 00:19:29.703 --> 00:19:50.590 (1169.703-1190.59)
🎯 Found sprite coordinates: 320,528,160,88
🕒 Found time cue: 00:19:50.590 --> 00:20:11.478 (1190.59-1211.478)
🎯 Found sprite coordinates: 480,528,160,88
🕒 Found time cue: 00:20:11.478 --> 00:20:32.365 (1211.478-1232.365)
🎯 Found sprite coordinates: 640,528,160,88
🕒 Found time cue: 00:20:32.365 --> 00:20:53.253 (1232.365-1253.253)
🎯 Found sprite coordinates: 800,528,160,88
🕒 Found time cue: 00:20:53.253 --> 00:21:14.140 (1253.253-1274.14)
🎯 Found sprite coordinates: 960,528,160,88
🕒 Found time cue: 00:21:14.140 --> 00:21:35.028 (1274.14-1295.028)
🎯 Found sprite coordinates: 1120,528,160,88
🕒 Found time cue: 00:21:35.028 --> 00:21:55.915 (1295.028-1315.915)
🎯 Found sprite coordinates: 1280,528,160,88
🕒 Found time cue: 00:21:55.915 --> 00:22:16.803 (1315.915-1336.803)
🎯 Found sprite coordinates: 0,616,160,88
🕒 Found time cue: 00:22:16.803 --> 00:22:37.691 (1336.803-1357.691)
🎯 Found sprite coordinates: 160,616,160,88
🕒 Found time cue: 00:22:37.691 --> 00:22:58.578 (1357.691-1378.578)
🎯 Found sprite coordinates: 320,616,160,88
🕒 Found time cue: 00:22:58.578 --> 00:23:19.466 (1378.578-1399.466)
🎯 Found sprite coordinates: 480,616,160,88
🕒 Found time cue: 00:23:19.466 --> 00:23:40.353 (1399.466-1420.353)
🎯 Found sprite coordinates: 640,616,160,88
🕒 Found time cue: 00:23:40.353 --> 00:24:01.241 (1420.353-1441.241)
🎯 Found sprite coordinates: 800,616,160,88
🕒 Found time cue: 00:24:01.241 --> 00:24:22.128 (1441.241-1462.128)
🎯 Found sprite coordinates: 960,616,160,88
🕒 Found time cue: 00:24:22.128 --> 00:24:43.016 (1462.128-1483.016)
🎯 Found sprite coordinates: 1120,616,160,88
🕒 Found time cue: 00:24:43.016 --> 00:25:03.903 (1483.016-1503.903)
🎯 Found sprite coordinates: 1280,616,160,88
🕒 Found time cue: 00:25:03.903 --> 00:25:24.791 (1503.903-1524.791)
🎯 Found sprite coordinates: 0,704,160,88
🕒 Found time cue: 00:25:24.791 --> 00:25:45.679 (1524.791-1545.679)
🎯 Found sprite coordinates: 160,704,160,88
🕒 Found time cue: 00:25:45.679 --> 00:26:06.566 (1545.679-1566.566)
🎯 Found sprite coordinates: 320,704,160,88
🕒 Found time cue: 00:26:06.566 --> 00:26:27.454 (1566.566-1587.454)
🎯 Found sprite coordinates: 480,704,160,88
🕒 Found time cue: 00:26:27.454 --> 00:26:48.341 (1587.454-1608.341)
🎯 Found sprite coordinates: 640,704,160,88
🕒 Found time cue: 00:26:48.341 --> 00:27:09.229 (1608.341-1629.229)
🎯 Found sprite coordinates: 800,704,160,88
🕒 Found time cue: 00:27:09.229 --> 00:27:30.116 (1629.229-1650.116)
🎯 Found sprite coordinates: 960,704,160,88
🕒 Found time cue: 00:27:30.116 --> 00:27:51.004 (1650.116-1671.004)
🎯 Found sprite coordinates: 1120,704,160,88
🕒 Found time cue: 00:27:51.004 --> 00:28:11.891 (1671.004-1691.891)
🎯 Found sprite coordinates: 1280,704,160,88
✅ Parsed 81 thumbnail entries from VTT content
✅ Loaded 81 VTT entries from mounted location or server
🔍 No oshash found in fingerprints, attempting to fetch it directly
✅ Found oshash fingerprint via API: 9a6da7b8d0b06712
🔑 Created sprite URL with fetched oshash: http://192.168.86.100:9999/scene/9a6da7b8d0b06712_sprite.jpg?apikey=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOiJjayIsInN1YiI6IkFQSUtleSIsImlhdCI6MTczMTgwOTM2Mn0.7AOyZqTzyDsSnuDx__RBhuIIkoPg2btebToAlpK1zXo
🔍 Attempting to load sprite sheet from local or remote: http://192.168.86.100:9999/scene/9a6da7b8d0b06712_sprite.jpg?apikey=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOiJjayIsInN1YiI6IkFQSUtleSIsImlhdCI6MTczMTgwOTM2Mn0.7AOyZqTzyDsSnuDx__RBhuIIkoPg2btebToAlpK1zXo
🔍 Loading sprite from remote URL
✅ Loaded sprite sheet: 1440.0x792.0
✅ Audio cleanup complete
🎬 Audio cleanup pause complete, proceeding with player setup
🔁 Auto-fallback: Attempt #4 of 5 with direct streaming
🎬 Initial streaming format: Direct
🎬 Creating stream request for scene 815, useHLS: false
📡 GraphQL Response Status: 200
📡 GraphQL Response: {"data":{"findScene":{"id":"815","title":"","details":"","url":null,"date":null,"rating100":null,"organized":false,"o_counter":0,"paths":{"screenshot":"http://192.168.86.100:9999/scene/815/screenshot?t=1723490951","preview":"http://192.168.86.100:9999/scene/815/preview","stream":"http://192.168.86.100:9999/scene/815/stream?apikey=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOiJjayIsInN1YiI6IkFQSUtleSIsImlhdCI6MTczMTgwOTM2Mn0.7AOyZqTzyDsSnuDx__RBhuIIkoPg2btebToAlpK1zXo","webp":"http://192.168.86.100:9999/scene/815/webp","vtt":"http://192.168.86.100:9999/scene/9a6da7b8d0b06712_thumbs.vtt","sprite":"http://192.168.86.100:9999/scene/9a6da7b8d0b06712_sprite.jpg","funscript":"http://192.168.86.100:9999/scene/815/funscript","interactive_heatmap":"http://192.168.86.100:9999/scene/815/interactive_heatmap"},"files":[{"size":159550238,"duration":1693.61,"video_codec":"hevc","width":576,"height":320}],"performers":[],"tags":[],"studio":null,"stash_ids":[],"created_at":"2024-08-12T09:00:19-04:00","updated_at":"2024-08-12T15:29:11-04:00"}}}
🎬 Scene 815 is VR content: false
🎬 Using direct streaming for this request
🎬 Using direct streaming
🎬 Created stream URL: http://192.168.86.100:9999/scene/815/stream?apikey=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOiJjayIsInN1YiI6IkFQSUtleSIsImlhdCI6MTczMTgwOTM2Mn0.7AOyZqTzyDsSnuDx__RBhuIIkoPg2btebToAlpK1zXo&t=0
🔑 Authentication headers set: ApiKey and Bearer token
🎬 Using direct streaming URL: http://192.168.86.100:9999/scene/815/stream?apikey=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOiJjayIsInN1YiI6IkFQSUtleSIsImlhdCI6MTczMTgwOTM2Mn0.7AOyZqTzyDsSnuDx__RBhuIIkoPg2btebToAlpK1zXo&t=0
⚠️ Asset preloading failed: Cannot Open
📝 Registering preview player in global manager
⚠️ Playback not likely to keep up - buffer issues
📊 Stall counter: 4/3
⚠️ Multiple consecutive stalls detected in direct playback mode
⚠️ Playback buffer empty
✅ Player setup complete
🎬 Creating video player view
🎬 Setting up player layer
🔍 Final sanity check - Player: true, Item: true, Duration: false, Playing: false, Pos: 0.0
⚠️ Critical playback failure detected in sanity check
🎬 Player layer configuration:
- Frame: (0.0, 0.0, 0.0, 0.0)
- Video gravity: AVLayerVideoGravity(_rawValue: AVLayerVideoGravityResizeAspect)
- Draws asynchronously: true
⏳ Player is waiting to play
⏳ Player is waiting to play
❌ Mounted VTT directory not found or couldn't be read
🔍 No oshash found in fingerprints, attempting to fetch it directly
📏 PlayerContainerView size changed from (0.0, 0.0) to (1280.0, 720.0)
✅ Found oshash fingerprint via API: 9a6da7b8d0b06712
🔑 Created sprite URL with fetched oshash: http://192.168.86.100:9999/scene/9a6da7b8d0b06712_sprite.jpg?apikey=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOiJjayIsInN1YiI6IkFQSUtleSIsImlhdCI6MTczMTgwOTM2Mn0.7AOyZqTzyDsSnuDx__RBhuIIkoPg2btebToAlpK1zXo
⏳ Player is waiting to play
❌ Player item failed: Optional(Error Domain=AVFoundationErrorDomain Code=-11828 "Cannot Open" UserInfo={NSLocalizedFailureReason=This media format is not supported., NSLocalizedDescription=Cannot Open, NSUnderlyingError=0x60000020d3e0 {Error Domain=NSOSStatusErrorDomain Code=-12847 "(null)"}})
❌ Error domain: AVFoundationErrorDomain
❌ Error code: -11828
❌ Underlying error: Error Domain=NSOSStatusErrorDomain Code=-12847 "(null)"
🚨 Critical AVFoundation error detected: Cannot Open - initiating immediate fallback
🔍 Attempting to load sprite sheet from local or remote: http://192.168.86.100:9999/scene/9a6da7b8d0b06712_sprite.jpg?apikey=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOiJjayIsInN1YiI6IkFQSUtleSIsImlhdCI6MTczMTgwOTM2Mn0.7AOyZqTzyDsSnuDx__RBhuIIkoPg2btebToAlpK1zXo
🔍 Loading sprite from remote URL
🚨 Critical playback failure detected - initiating immediate fallback
🔁 Critical failure: Retry attempt 4 of 5 with direct mode
🎬 Setting up player for scene: 815
⚠️ No fallback position found for scene 815
📊 Preserved playback position at 00:00 for fallback
🧹 Performing thorough player cleanup
🧹 Removed all KVO observers
⏸️ Player is paused
🧹 Removed time observer
⏸️ Player is paused
📝 Unregistering preview player from global manager
🧹 Unregistered player from global manager
✅ Audio session explicitly reset
⏹️ Performing safe audio cleanup
✅ Audio session reset successfully
✅ Used global manager for additional audio cleanup
✅ Player cleanup complete
🧹 CRITICAL: Clearing all caches and state data for proper reset
🧹 Reset all cached data for new video (scene ID: 815)
🔄 StashAPI initializing with server: http://192.168.86.100:9999
🎬 Cleaning up player view
🔄 Checking connection status...
🔄 Checking server connection to http://192.168.86.100:9999
📤 Sending connection check request...
✅ Loaded sprite sheet: 1440.0x792.0
📡 Server responded with status code: 200
📥 Response: {"data":{"findPerformers":{"count":955,"performers":[{"id":"55","name":"Aaliyah Love"}]}}}...
✅ Server connection successful
📊 Performers data: ["performers": <__NSSingleObjectArrayI 0x6000012327b0>(
{
    id = 55;
    name = "Aaliyah Love";
}
)
, "count": 955]
✅ Connection successful
✅ Audio cleanup complete
▶️ Forced play after direct mode retry
🎬 Audio cleanup pause complete, proceeding with player setup
🔁 Auto-fallback: Attempt #5 of 5 with direct streaming
🎬 Initial streaming format: Direct
🎬 Creating stream request for scene 815, useHLS: false
📡 GraphQL Response Status: 200
📡 GraphQL Response: {"data":{"findScene":{"id":"815","title":"","details":"","url":null,"date":null,"rating100":null,"organized":false,"o_counter":0,"paths":{"screenshot":"http://192.168.86.100:9999/scene/815/screenshot?t=1723490951","preview":"http://192.168.86.100:9999/scene/815/preview","stream":"http://192.168.86.100:9999/scene/815/stream?apikey=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOiJjayIsInN1YiI6IkFQSUtleSIsImlhdCI6MTczMTgwOTM2Mn0.7AOyZqTzyDsSnuDx__RBhuIIkoPg2btebToAlpK1zXo","webp":"http://192.168.86.100:9999/scene/815/webp","vtt":"http://192.168.86.100:9999/scene/9a6da7b8d0b06712_thumbs.vtt","sprite":"http://192.168.86.100:9999/scene/9a6da7b8d0b06712_sprite.jpg","funscript":"http://192.168.86.100:9999/scene/815/funscript","interactive_heatmap":"http://192.168.86.100:9999/scene/815/interactive_heatmap"},"files":[{"size":159550238,"duration":1693.61,"video_codec":"hevc","width":576,"height":320}],"performers":[],"tags":[],"studio":null,"stash_ids":[],"created_at":"2024-08-12T09:00:19-04:00","updated_at":"2024-08-12T15:29:11-04:00"}}}
🎬 Scene 815 is VR content: false
🎬 Using direct streaming for this request
🎬 Using direct streaming
🎬 Created stream URL: http://192.168.86.100:9999/scene/815/stream?apikey=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOiJjayIsInN1YiI6IkFQSUtleSIsImlhdCI6MTczMTgwOTM2Mn0.7AOyZqTzyDsSnuDx__RBhuIIkoPg2btebToAlpK1zXo&t=0
🔑 Authentication headers set: ApiKey and Bearer token
🎬 Using direct streaming URL: http://192.168.86.100:9999/scene/815/stream?apikey=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOiJjayIsInN1YiI6IkFQSUtleSIsImlhdCI6MTczMTgwOTM2Mn0.7AOyZqTzyDsSnuDx__RBhuIIkoPg2btebToAlpK1zXo&t=0
⚠️ Asset preloading failed: Cannot Open
📝 Registering preview player in global manager
⚠️ Playback not likely to keep up - buffer issues
📊 Stall counter: 5/3
⚠️ Multiple consecutive stalls detected in direct playback mode
⚠️ Playback buffer empty
✅ Player setup complete
🎬 Creating video player view
🎬 Setting up player layer
📏 PlayerContainerView size changed from (0.0, 0.0) to (1280.0, 720.0)
🎬 Player layer configuration:
- Frame: (0.0, 0.0, 1280.0, 720.0)
- Video gravity: AVLayerVideoGravity(_rawValue: AVLayerVideoGravityResizeAspect)
- Draws asynchronously: true
⏳ Player is waiting to play
⏳ Player is waiting to play
❌ Mounted VTT directory not found or couldn't be read
❌ Player item failed: Optional(Error Domain=AVFoundationErrorDomain Code=-11828 "Cannot Open" UserInfo={NSLocalizedFailureReason=This media format is not supported., NSLocalizedDescription=Cannot Open, NSUnderlyingError=0x60000026b540 {Error Domain=NSOSStatusErrorDomain Code=-12847 "(null)"}})
❌ Error domain: AVFoundationErrorDomain
❌ Error code: -11828
❌ Underlying error: Error Domain=NSOSStatusErrorDomain Code=-12847 "(null)"
🚨 Critical AVFoundation error detected: Cannot Open - initiating immediate fallback
⏳ Player is waiting to play
🚨 Critical playback failure detected - initiating immediate fallback
🔄 Critical failure: Switching to HLS mode after 5 direct playback attempts
💾 Saved HLS mode preference: true
📊 Using fallback position: 00:00
🎯 CRITICAL: Preserving position 0:00 for scene 815 in case of fallback
🎯 Position 0:00 preserved for scene 815
🎯 Critical failure: Explicitly preserving position 00:00 for HLS fallback
🎬 Setting up player for scene: 815
🎯 Retrieved fallback position from memory: 0:00
🎯 FOUND PRESERVED POSITION: Using saved position 00:00 for scene 815
🧹 Cleared fallback position for scene 815
📊 Preserved playback position at 00:00 for fallback
🧹 Performing thorough player cleanup
🧹 Removed all KVO observers
⏸️ Player is paused
🧹 Removed time observer
⏸️ Player is paused
📝 Unregistering preview player from global manager
🧹 Unregistered player from global manager
✅ Audio session explicitly reset
⏹️ Performing safe audio cleanup
✅ Audio session reset successfully
✅ Used global manager for additional audio cleanup
✅ Player cleanup complete
🔍 No oshash found in fingerprints for VTT, attempting to fetch it directly
🧹 CRITICAL: Clearing all caches and state data for proper reset
🧹 Reset all cached data for new video (scene ID: 815)
🔄 StashAPI initializing with server: http://192.168.86.100:9999
✅ Found oshash fingerprint via API for VTT: 9a6da7b8d0b06712
🔑 Created VTT URL with fetched oshash: http://192.168.86.100:9999/scene/9a6da7b8d0b06712_thumbs.vtt?apikey=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOiJjayIsInN1YiI6IkFQSUtleSIsImlhdCI6MTczMTgwOTM2Mn0.7AOyZqTzyDsSnuDx__RBhuIIkoPg2btebToAlpK1zXo
🎬 Cleaning up player view
🔄 Checking connection status...
🔄 Checking server connection to http://192.168.86.100:9999
📤 Sending connection check request...
🔍 Attempting to load VTT from local or remote: http://192.168.86.100:9999/scene/9a6da7b8d0b06712_thumbs.vtt?apikey=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOiJjayIsInN1YiI6IkFQSUtleSIsImlhdCI6MTczMTgwOTM2Mn0.7AOyZqTzyDsSnuDx__RBhuIIkoPg2btebToAlpK1zXo
🔍 Attempting to parse VTT from URL: http://192.168.86.100:9999/scene/9a6da7b8d0b06712_thumbs.vtt?apikey=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOiJjayIsInN1YiI6IkFQSUtleSIsImlhdCI6MTczMTgwOTM2Mn0.7AOyZqTzyDsSnuDx__RBhuIIkoPg2btebToAlpK1zXo
🌐 VTT HTTP response: 200
🔍 VTT content preview: WEBVTT

00:00:00.000 --> 00:00:20.887
9a6da7b8d0b06712_sprite.jpg#xywh=0,0,160,88

00:00:20.887 --> 00:00:41.775
9a6da7b8d0b06712_sprite.jpg#xywh=160,0,160,88

00:00:41.775 --> 00:01:02.662
9a6da7b8d0...
🔍 Parsing 245 lines from VTT content
🕒 Found time cue: 00:00:00.000 --> 00:00:20.887 (0.0-20.887)
🎯 Found sprite coordinates: 0,0,160,88
🕒 Found time cue: 00:00:20.887 --> 00:00:41.775 (20.887-41.775)
🎯 Found sprite coordinates: 160,0,160,88
🕒 Found time cue: 00:00:41.775 --> 00:01:02.662 (41.775-62.662)
🎯 Found sprite coordinates: 320,0,160,88
🕒 Found time cue: 00:01:02.662 --> 00:01:23.550 (62.662-83.55)
🎯 Found sprite coordinates: 480,0,160,88
🕒 Found time cue: 00:01:23.550 --> 00:01:44.437 (83.55-104.437)
🎯 Found sprite coordinates: 640,0,160,88
🕒 Found time cue: 00:01:44.437 --> 00:02:05.325 (104.437-125.325)
🎯 Found sprite coordinates: 800,0,160,88
🕒 Found time cue: 00:02:05.325 --> 00:02:26.212 (125.325-146.212)
🎯 Found sprite coordinates: 960,0,160,88
🕒 Found time cue: 00:02:26.212 --> 00:02:47.100 (146.212-167.1)
🎯 Found sprite coordinates: 1120,0,160,88
🕒 Found time cue: 00:02:47.100 --> 00:03:07.987 (167.1-187.987)
🎯 Found sprite coordinates: 1280,0,160,88
🕒 Found time cue: 00:03:07.987 --> 00:03:28.875 (187.987-208.875)
🎯 Found sprite coordinates: 0,88,160,88
🕒 Found time cue: 00:03:28.875 --> 00:03:49.763 (208.875-229.763)
🎯 Found sprite coordinates: 160,88,160,88
🕒 Found time cue: 00:03:49.763 --> 00:04:10.650 (229.763-250.65)
🎯 Found sprite coordinates: 320,88,160,88
🕒 Found time cue: 00:04:10.650 --> 00:04:31.538 (250.65-271.538)
🎯 Found sprite coordinates: 480,88,160,88
🕒 Found time cue: 00:04:31.538 --> 00:04:52.425 (271.538-292.425)
🎯 Found sprite coordinates: 640,88,160,88
🕒 Found time cue: 00:04:52.425 --> 00:05:13.313 (292.425-313.313)
🎯 Found sprite coordinates: 800,88,160,88
🕒 Found time cue: 00:05:13.313 --> 00:05:34.200 (313.313-334.2)
🎯 Found sprite coordinates: 960,88,160,88
🕒 Found time cue: 00:05:34.200 --> 00:05:55.088 (334.2-355.088)
🎯 Found sprite coordinates: 1120,88,160,88
🕒 Found time cue: 00:05:55.088 --> 00:06:15.975 (355.088-375.975)
🎯 Found sprite coordinates: 1280,88,160,88
🕒 Found time cue: 00:06:15.975 --> 00:06:36.863 (375.975-396.863)
🎯 Found sprite coordinates: 0,176,160,88
🕒 Found time cue: 00:06:36.863 --> 00:06:57.751 (396.863-417.751)
🎯 Found sprite coordinates: 160,176,160,88
🕒 Found time cue: 00:06:57.751 --> 00:07:18.638 (417.751-438.638)
🎯 Found sprite coordinates: 320,176,160,88
🕒 Found time cue: 00:07:18.638 --> 00:07:39.526 (438.638-459.526)
🎯 Found sprite coordinates: 480,176,160,88
🕒 Found time cue: 00:07:39.526 --> 00:08:00.413 (459.526-480.413)
🎯 Found sprite coordinates: 640,176,160,88
🕒 Found time cue: 00:08:00.413 --> 00:08:21.301 (480.413-501.301)
🎯 Found sprite coordinates: 800,176,160,88
🕒 Found time cue: 00:08:21.301 --> 00:08:42.188 (501.301-522.188)
🎯 Found sprite coordinates: 960,176,160,88
🕒 Found time cue: 00:08:42.188 --> 00:09:03.076 (522.188-543.076)
🎯 Found sprite coordinates: 1120,176,160,88
🕒 Found time cue: 00:09:03.076 --> 00:09:23.963 (543.076-563.963)
🎯 Found sprite coordinates: 1280,176,160,88
🕒 Found time cue: 00:09:23.963 --> 00:09:44.851 (563.963-584.851)
🎯 Found sprite coordinates: 0,264,160,88
🕒 Found time cue: 00:09:44.851 --> 00:10:05.739 (584.851-605.739)
🎯 Found sprite coordinates: 160,264,160,88
🕒 Found time cue: 00:10:05.739 --> 00:10:26.626 (605.739-626.626)
🎯 Found sprite coordinates: 320,264,160,88
🕒 Found time cue: 00:10:26.626 --> 00:10:47.514 (626.626-647.514)
🎯 Found sprite coordinates: 480,264,160,88
🕒 Found time cue: 00:10:47.514 --> 00:11:08.401 (647.514-668.401)
🎯 Found sprite coordinates: 640,264,160,88
🕒 Found time cue: 00:11:08.401 --> 00:11:29.289 (668.401-689.289)
🎯 Found sprite coordinates: 800,264,160,88
🕒 Found time cue: 00:11:29.289 --> 00:11:50.176 (689.289-710.176)
🎯 Found sprite coordinates: 960,264,160,88
🕒 Found time cue: 00:11:50.176 --> 00:12:11.064 (710.176-731.064)
🎯 Found sprite coordinates: 1120,264,160,88
🕒 Found time cue: 00:12:11.064 --> 00:12:31.951 (731.064-751.951)
🎯 Found sprite coordinates: 1280,264,160,88
🕒 Found time cue: 00:12:31.951 --> 00:12:52.839 (751.951-772.8389999999999)
🎯 Found sprite coordinates: 0,352,160,88
🕒 Found time cue: 00:12:52.839 --> 00:13:13.727 (772.8389999999999-793.727)
🎯 Found sprite coordinates: 160,352,160,88
🕒 Found time cue: 00:13:13.727 --> 00:13:34.614 (793.727-814.614)
🎯 Found sprite coordinates: 320,352,160,88
🕒 Found time cue: 00:13:34.614 --> 00:13:55.502 (814.614-835.502)
🎯 Found sprite coordinates: 480,352,160,88
🕒 Found time cue: 00:13:55.502 --> 00:14:16.389 (835.502-856.389)
🎯 Found sprite coordinates: 640,352,160,88
🕒 Found time cue: 00:14:16.389 --> 00:14:37.277 (856.389-877.277)
🎯 Found sprite coordinates: 800,352,160,88
🕒 Found time cue: 00:14:37.277 --> 00:14:58.164 (877.277-898.164)
🎯 Found sprite coordinates: 960,352,160,88
🕒 Found time cue: 00:14:58.164 --> 00:15:19.052 (898.164-919.052)
🎯 Found sprite coordinates: 1120,352,160,88
🕒 Found time cue: 00:15:19.052 --> 00:15:39.939 (919.052-939.939)
🎯 Found sprite coordinates: 1280,352,160,88
🕒 Found time cue: 00:15:39.939 --> 00:16:00.827 (939.939-960.827)
🎯 Found sprite coordinates: 0,440,160,88
🕒 Found time cue: 00:16:00.827 --> 00:16:21.715 (960.827-981.715)
🎯 Found sprite coordinates: 160,440,160,88
🕒 Found time cue: 00:16:21.715 --> 00:16:42.602 (981.715-1002.602)
🎯 Found sprite coordinates: 320,440,160,88
🕒 Found time cue: 00:16:42.602 --> 00:17:03.490 (1002.602-1023.49)
🎯 Found sprite coordinates: 480,440,160,88
🕒 Found time cue: 00:17:03.490 --> 00:17:24.377 (1023.49-1044.377)
🎯 Found sprite coordinates: 640,440,160,88
🕒 Found time cue: 00:17:24.377 --> 00:17:45.265 (1044.377-1065.265)
🎯 Found sprite coordinates: 800,440,160,88
🕒 Found time cue: 00:17:45.265 --> 00:18:06.152 (1065.265-1086.152)
🎯 Found sprite coordinates: 960,440,160,88
🕒 Found time cue: 00:18:06.152 --> 00:18:27.040 (1086.152-1107.04)
🎯 Found sprite coordinates: 1120,440,160,88
🕒 Found time cue: 00:18:27.040 --> 00:18:47.927 (1107.04-1127.927)
🎯 Found sprite coordinates: 1280,440,160,88
🕒 Found time cue: 00:18:47.927 --> 00:19:08.815 (1127.927-1148.815)
🎯 Found sprite coordinates: 0,528,160,88
🕒 Found time cue: 00:19:08.815 --> 00:19:29.703 (1148.815-1169.703)
🎯 Found sprite coordinates: 160,528,160,88
🕒 Found time cue: 00:19:29.703 --> 00:19:50.590 (1169.703-1190.59)
🎯 Found sprite coordinates: 320,528,160,88
🕒 Found time cue: 00:19:50.590 --> 00:20:11.478 (1190.59-1211.478)
🎯 Found sprite coordinates: 480,528,160,88
🕒 Found time cue: 00:20:11.478 --> 00:20:32.365 (1211.478-1232.365)
🎯 Found sprite coordinates: 640,528,160,88
🕒 Found time cue: 00:20:32.365 --> 00:20:53.253 (1232.365-1253.253)
🎯 Found sprite coordinates: 800,528,160,88
🕒 Found time cue: 00:20:53.253 --> 00:21:14.140 (1253.253-1274.14)
🎯 Found sprite coordinates: 960,528,160,88
🕒 Found time cue: 00:21:14.140 --> 00:21:35.028 (1274.14-1295.028)
🎯 Found sprite coordinates: 1120,528,160,88
🕒 Found time cue: 00:21:35.028 --> 00:21:55.915 (1295.028-1315.915)
🎯 Found sprite coordinates: 1280,528,160,88
🕒 Found time cue: 00:21:55.915 --> 00:22:16.803 (1315.915-1336.803)
🎯 Found sprite coordinates: 0,616,160,88
🕒 Found time cue: 00:22:16.803 --> 00:22:37.691 (1336.803-1357.691)
🎯 Found sprite coordinates: 160,616,160,88
🕒 Found time cue: 00:22:37.691 --> 00:22:58.578 (1357.691-1378.578)
🎯 Found sprite coordinates: 320,616,160,88
🕒 Found time cue: 00:22:58.578 --> 00:23:19.466 (1378.578-1399.466)
🎯 Found sprite coordinates: 480,616,160,88
🕒 Found time cue: 00:23:19.466 --> 00:23:40.353 (1399.466-1420.353)
🎯 Found sprite coordinates: 640,616,160,88
🕒 Found time cue: 00:23:40.353 --> 00:24:01.241 (1420.353-1441.241)
🎯 Found sprite coordinates: 800,616,160,88
🕒 Found time cue: 00:24:01.241 --> 00:24:22.128 (1441.241-1462.128)
🎯 Found sprite coordinates: 960,616,160,88
🕒 Found time cue: 00:24:22.128 --> 00:24:43.016 (1462.128-1483.016)
🎯 Found sprite coordinates: 1120,616,160,88
🕒 Found time cue: 00:24:43.016 --> 00:25:03.903 (1483.016-1503.903)
🎯 Found sprite coordinates: 1280,616,160,88
🕒 Found time cue: 00:25:03.903 --> 00:25:24.791 (1503.903-1524.791)
🎯 Found sprite coordinates: 0,704,160,88
🕒 Found time cue: 00:25:24.791 --> 00:25:45.679 (1524.791-1545.679)
🎯 Found sprite coordinates: 160,704,160,88
🕒 Found time cue: 00:25:45.679 --> 00:26:06.566 (1545.679-1566.566)
🎯 Found sprite coordinates: 320,704,160,88
🕒 Found time cue: 00:26:06.566 --> 00:26:27.454 (1566.566-1587.454)
🎯 Found sprite coordinates: 480,704,160,88
🕒 Found time cue: 00:26:27.454 --> 00:26:48.341 (1587.454-1608.341)
🎯 Found sprite coordinates: 640,704,160,88
🕒 Found time cue: 00:26:48.341 --> 00:27:09.229 (1608.341-1629.229)
🎯 Found sprite coordinates: 800,704,160,88
🕒 Found time cue: 00:27:09.229 --> 00:27:30.116 (1629.229-1650.116)
🎯 Found sprite coordinates: 960,704,160,88
🕒 Found time cue: 00:27:30.116 --> 00:27:51.004 (1650.116-1671.004)
🎯 Found sprite coordinates: 1120,704,160,88
🕒 Found time cue: 00:27:51.004 --> 00:28:11.891 (1671.004-1691.891)
🎯 Found sprite coordinates: 1280,704,160,88
✅ Parsed 81 thumbnail entries from VTT content
✅ Loaded 81 VTT entries from mounted location or server
📡 Server responded with status code: 200
📥 Response: {"data":{"findPerformers":{"count":955,"performers":[{"id":"55","name":"Aaliyah Love"}]}}}...
✅ Server connection successful
📊 Performers data: ["count": 955, "performers": <__NSSingleObjectArrayI 0x6000012399c0>(
{
    id = 55;
    name = "Aaliyah Love";
}
)
]
✅ Connection successful
🔍 No oshash found in fingerprints, attempting to fetch it directly
✅ Found oshash fingerprint via API: 9a6da7b8d0b06712
🔑 Created sprite URL with fetched oshash: http://192.168.86.100:9999/scene/9a6da7b8d0b06712_sprite.jpg?apikey=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOiJjayIsInN1YiI6IkFQSUtleSIsImlhdCI6MTczMTgwOTM2Mn0.7AOyZqTzyDsSnuDx__RBhuIIkoPg2btebToAlpK1zXo
🔍 Attempting to load sprite sheet from local or remote: http://192.168.86.100:9999/scene/9a6da7b8d0b06712_sprite.jpg?apikey=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOiJjayIsInN1YiI6IkFQSUtleSIsImlhdCI6MTczMTgwOTM2Mn0.7AOyZqTzyDsSnuDx__RBhuIIkoPg2btebToAlpK1zXo
🔍 Loading sprite from remote URL
✅ Loaded sprite sheet: 1440.0x792.0
✅ Audio cleanup complete
▶️ Forced play after direct mode retry
🎬 Audio cleanup pause complete, proceeding with player setup
🔁 Auto-fallback: Attempt #6 of 5 with HLS streaming
🎬 Initial streaming format: HLS
🎬 Creating stream request for scene 815, useHLS: true
📡 GraphQL Response Status: 200
📡 GraphQL Response: {"data":{"findScene":{"id":"815","title":"","details":"","url":null,"date":null,"rating100":null,"organized":false,"o_counter":0,"paths":{"screenshot":"http://192.168.86.100:9999/scene/815/screenshot?t=1723490951","preview":"http://192.168.86.100:9999/scene/815/preview","stream":"http://192.168.86.100:9999/scene/815/stream?apikey=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOiJjayIsInN1YiI6IkFQSUtleSIsImlhdCI6MTczMTgwOTM2Mn0.7AOyZqTzyDsSnuDx__RBhuIIkoPg2btebToAlpK1zXo","webp":"http://192.168.86.100:9999/scene/815/webp","vtt":"http://192.168.86.100:9999/scene/9a6da7b8d0b06712_thumbs.vtt","sprite":"http://192.168.86.100:9999/scene/9a6da7b8d0b06712_sprite.jpg","funscript":"http://192.168.86.100:9999/scene/815/funscript","interactive_heatmap":"http://192.168.86.100:9999/scene/815/interactive_heatmap"},"files":[{"size":159550238,"duration":1693.61,"video_codec":"hevc","width":576,"height":320}],"performers":[],"tags":[],"studio":null,"stash_ids":[],"created_at":"2024-08-12T09:00:19-04:00","updated_at":"2024-08-12T15:29:11-04:00"}}}
🎬 Scene 815 is VR content: false
🎬 Using HLS streaming for this request
🎬 Using HLS streaming
🎬 Created stream URL: http://192.168.86.100:9999/scene/815/stream.m3u8?apikey=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOiJjayIsInN1YiI6IkFQSUtleSIsImlhdCI6MTczMTgwOTM2Mn0.7AOyZqTzyDsSnuDx__RBhuIIkoPg2btebToAlpK1zXo&resolution=ORIGINAL&t=0
🔑 Authentication headers set: ApiKey and Bearer token
🎬 Using HLS streaming URL: http://192.168.86.100:9999/scene/815/stream.m3u8?apikey=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOiJjayIsInN1YiI6IkFQSUtleSIsImlhdCI6MTczMTgwOTM2Mn0.7AOyZqTzyDsSnuDx__RBhuIIkoPg2btebToAlpK1zXo&resolution=ORIGINAL&t=0
📝 Registering preview player in global manager
⚠️ Playback not likely to keep up - buffer issues
⚠️ Playback buffer empty
✅ Player setup complete
🎬 Creating video player view
🎬 Setting up player layer
📏 PlayerContainerView size changed from (0.0, 0.0) to (1280.0, 720.0)
🎬 Player layer configuration:
- Frame: (0.0, 0.0, 1280.0, 720.0)
- Video gravity: AVLayerVideoGravity(_rawValue: AVLayerVideoGravityResizeAspect)
- Draws asynchronously: true
⏳ Player is waiting to play
⏳ Player is waiting to play
❌ Mounted VTT directory not found or couldn't be read
▶️ Forced play after direct mode retry
⏳ Player is waiting to play
🔍 No oshash found in fingerprints, attempting to fetch it directly
✅ Found oshash fingerprint via API: 9a6da7b8d0b06712
🔑 Created sprite URL with fetched oshash: http://192.168.86.100:9999/scene/9a6da7b8d0b06712_sprite.jpg?apikey=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOiJjayIsInN1YiI6IkFQSUtleSIsImlhdCI6MTczMTgwOTM2Mn0.7AOyZqTzyDsSnuDx__RBhuIIkoPg2btebToAlpK1zXo
🔍 Attempting to load sprite sheet from local or remote: http://192.168.86.100:9999/scene/9a6da7b8d0b06712_sprite.jpg?apikey=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOiJjayIsInN1YiI6IkFQSUtleSIsImlhdCI6MTczMTgwOTM2Mn0.7AOyZqTzyDsSnuDx__RBhuIIkoPg2btebToAlpK1zXo
🔍 Loading sprite from remote URL
✅ Loaded sprite sheet: 1440.0x792.0
▶️ Forced play after direct mode retry
🔍 5-second playback check: time=nan, playing=no
▶️ Player is playing
✅ Player item ready to play
🎬 Video duration: 28:13
✅ Seeked to time: 00:00
▶️ Player is playing
▶️ Player is playing
▶️ Started playback after seeking to 00:00
▶️ Forced play after HLS mode switch
▶️ Player is playing
▶️ Player is playing
▶️ Player is playing
🔍 Final sanity check - Player: true, Item: true, Duration: true, Playing: true, Pos: 0.500094049
✅ Playback is now playing, no more play commands needed
▶️ Player is playing
🎬 Starting CRITICAL CLEANUP process for video player
🧹 Performing thorough player cleanup
🧹 Removed all KVO observers
⏸️ Player is paused
🧹 Removed time observer
⏸️ Player is paused
📝 Unregistering preview player from global manager
🧹 Unregistered player from global manager
✅ Audio session explicitly reset
⏹️ Performing safe audio cleanup
✅ Audio session reset successfully
✅ Used global manager for additional audio cleanup
✅ Player cleanup complete
✅ Video player cleanup complete
🔇 Muting all preview players
🧹 Performing thorough player cleanup
🧹 Removed all KVO observers
⏸️ Player is paused
📝 Unregistering preview player from global manager
🧹 Unregistered player from global manager
✅ Audio session explicitly reset
⚠️ Already cleaning up, skipping duplicate call
✅ Used global manager for additional audio cleanup
✅ Player cleanup complete
🎭 Found 0 total performers, 0 are female
🎭 No female performers found, using all 0 performers instead
🎭 Scene has no performers at all
🧹 CRITICAL: Clearing all caches and state data for proper reset
🧹 CRITICAL: Clearing all caches and state data for proper reset
🎬 Cleaning up player view
✅ Audio cleanup complete
🔍 5-second playback check: time=nan, playing=no
🔍 5-second playback check: time=nan, playing=no
🔍 5-second playback check: time=nan, playing=no
🔍 5-second playback check: time=nan, playing=no
🔍 5-second playback check: time=nan, playing=no
🔍 5-second playback check: time=nan, playing=no