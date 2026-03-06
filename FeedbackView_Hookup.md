# FeedbackView Hookup Instructions
## Strong Gut – Xcode Integration

---

## Step 1 — Confirm the file is in your target

In Xcode's Project Navigator, click `FeedbackView.swift` and open the
File Inspector (right panel). Under **Target Membership**, make sure
your app target is checked.

---

## Step 2 — Add @State trigger to your result view

Open whichever view shows your analysis results
(e.g. `AnalysisResultView.swift` or `ContentView.swift`).

Add this property near the top of the struct:

```swift
@State private var showFeedback = false
```

---

## Step 3 — Add the feedback button

Find your analysis result card or the bottom of your results section.
Add a button to trigger the sheet:

```swift
Button {
    showFeedback = true
} label: {
    Label("Rate this analysis", systemImage: "hand.thumbsup")
        .font(.subheadline.weight(.medium))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
}
.padding(.top, 8)
```

---

## Step 4 — Attach the sheet

On your outermost view container (VStack, ScrollView, etc.), add:

```swift
.fullScreenCover(isPresented: $showFeedback) {
    FeedbackView(
        foodItem: "your food name here",   // ← replace with your variable
        backendURL: "https://web-production-825a4.up.railway.app",
        onDismiss: { showFeedback = false }
    )
}
```

### Passing the food name
If your result model has a food name, pass it directly. For example:

```swift
// If you have an AnalysisResult model:
FeedbackView(
    foodItem: analysisResult.foodName,
    backendURL: "https://web-production-825a4.up.railway.app",
    onDismiss: { showFeedback = false }
)

// If you're using a plain String state variable:
FeedbackView(
    foodItem: currentFoodItem,
    backendURL: "https://web-production-825a4.up.railway.app",
    onDismiss: { showFeedback = false }
)
```

---

## Step 5 — Transparent background fix (fullScreenCover)

`fullScreenCover` has a white background by default that hides
the frosted overlay effect. Add this helper struct to any file
(or at the bottom of FeedbackView.swift):

```swift
struct ClearBackgroundView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        DispatchQueue.main.async {
            view.superview?.superview?.backgroundColor = .clear
        }
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {}
}
```

Then update your fullScreenCover body:

```swift
.fullScreenCover(isPresented: $showFeedback) {
    FeedbackView(
        foodItem: currentFoodItem,
        backendURL: "https://web-production-825a4.up.railway.app",
        onDismiss: { showFeedback = false }
    )
    .background(ClearBackgroundView())
}
```

---

## Step 6 — Update main.py on Railway

Copy the contents of `main_feedback_addition.py` into your Railway
`main.py`. The two things to add are:

1. The `FeedbackPayload` Pydantic model
2. The `POST /feedback` endpoint
3. (Optional) The `GET /feedback/summary` endpoint

Then push to Railway:

```bash
git add main.py
git commit -m "Add anonymous feedback endpoint"
git push
```

Railway auto-deploys on push. Wait ~60 seconds and test with:

```bash
curl -X POST https://web-production-825a4.up.railway.app/feedback \
  -H "Content-Type: application/json" \
  -d '{
    "anonymousID": "test-123",
    "foodItem": "Avocado Toast",
    "selectedAnalysis": "Claude",
    "thumbsUp": true,
    "reason": "Very helpful",
    "timestamp": "2026-03-06T10:00:00"
  }'
```

Expected response: `{"status":"ok"}`

Check your summary:

```bash
curl https://web-production-825a4.up.railway.app/feedback/summary
```

---

## Minimal Complete Example

If you want the fastest possible integration, here is a self-contained
view that wires everything together:

```swift
struct AnalysisResultView: View {
    let foodItem: String
    let analysisText: String

    @State private var showFeedback = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                Text(analysisText)
                    .padding()

                Button {
                    showFeedback = true
                } label: {
                    Label("Rate this analysis", systemImage: "hand.thumbsup")
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                .frame(maxWidth: .infinity)
            }
        }
        .fullScreenCover(isPresented: $showFeedback) {
            FeedbackView(
                foodItem: foodItem,
                backendURL: "https://web-production-825a4.up.railway.app",
                onDismiss: { showFeedback = false }
            )
            .background(ClearBackgroundView())
        }
    }
}
```

---

## Troubleshooting

| Issue | Fix |
|---|---|
| Sheet has white background | Add `ClearBackgroundView()` per Step 5 |
| POST returns 422 | Check timestamp format — must be ISO 8601 |
| POST returns 404 | Railway hasn't deployed yet, wait 60s |
| Button not visible | Wrap in a `frame(maxWidth: .infinity)` |
| `foodItem` is empty string | Ensure your state variable is set before sheet opens |
