package com.luisbadalo.calmhome;

import android.app.Activity;
import android.app.AlertDialog;
import android.app.AppOpsManager;
import android.app.usage.UsageStats;
import android.app.usage.UsageStatsManager;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.BitmapDrawable;
import android.graphics.drawable.ColorDrawable;
import android.graphics.drawable.Drawable;
import android.graphics.drawable.GradientDrawable;
import android.graphics.drawable.LayerDrawable;
import android.os.Bundle;
import android.os.Process;
import android.net.Uri;
import android.provider.Settings;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.KeyEvent;
import android.view.View;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextClock;
import android.widget.TextView;
import android.widget.Toast;

import java.io.File;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

public class MainActivity extends Activity {

    // No saved/built-in app list. Android usage determines the six top-row apps.
    private static final String PREFS = "config";
    private static final List<String> NOT_APPS = Arrays.asList("com.android.vending", "com.android.tv.settings",
            "com.android.tv", "com.google.android.tv", "com.droidlogic.tvinput", "com.droidlogic.tvsource",
            "com.google.android.tvlauncher", "com.google.android.apps.tv.launcherx",
            "com.google.android.leanbacklauncher");
    private static final String PLAY_STORE = "com.android.vending";
    private static final String SETTINGS = "settings";
    private static final String ALL_APPS = "all-apps";
    private static final int PER_ROW = 6;
    private static final long HISTORY_MILLIS = 30L * 24 * 60 * 60 * 1000;

    // Layout is designed at 1920x1080 and scaled to the TV's real UI size by px().
    private static final int MARGIN = 96, GAP = 36, RADIUS = 22;
    private static final int ROW1_TOP = 604, ROW2_TOP = 828;
    private float scale = 1f;

    private static Typeface regular, semibold;

    private FrameLayout root;
    private final List<View> tiles = new ArrayList<>();
    private TextView rankingHint;
    private boolean rankedByUsage;
    private String focusedKey;

    private final BroadcastReceiver packagesChanged = new BroadcastReceiver() {
        @Override public void onReceive(Context c, Intent i) { if (root != null) buildTiles(); }
    };

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        // Drop the old fixed-list preference when updating from version 1.
        getSharedPreferences(PREFS, 0).edit().remove("apps").apply();
        loadFonts();
        scale = getResources().getDisplayMetrics().widthPixels / 1920f;
        getWindow().setBackgroundDrawable(background());

        root = new FrameLayout(this);
        root.setClipChildren(false);

        LinearLayout clock = new LinearLayout(this);
        clock.setOrientation(LinearLayout.VERTICAL);
        TextClock date = clock("EEEE, d MMMM", "EEEE, d MMMM", px(30), 0xA8FFFFFF, regular);
        TextClock time = clock("h:mm", "H:mm", px(176), Color.WHITE, semibold);
        time.setLetterSpacing(-0.028f);
        time.setFontFeatureSettings("tnum");
        time.setIncludeFontPadding(false);
        clock.addView(date);
        LinearLayout.LayoutParams tp = new LinearLayout.LayoutParams(-2, -2);
        tp.topMargin = px(-20); // pull the big digits up under the date
        clock.addView(time, tp);
        // A match-parent date must not inherit the narrower clock's width when
        // localized weekday/month names are longer than the current digits.
        root.addView(clock, at(px(MARGIN), px(92), px(900), -2));
        rankingHint = text(px(24), 0xA8FFFFFF, regular);
        root.addView(rankingHint, at(px(MARGIN), px(340), px(1400), -2));

        setContentView(root);

        IntentFilter f = new IntentFilter();
        f.addAction(Intent.ACTION_PACKAGE_ADDED);
        f.addAction(Intent.ACTION_PACKAGE_REMOVED);
        f.addAction(Intent.ACTION_PACKAGE_CHANGED);
        f.addDataScheme("package");
        if (android.os.Build.VERSION.SDK_INT >= 33) registerReceiver(packagesChanged, f, Context.RECEIVER_EXPORTED);
        else registerReceiver(packagesChanged, f);
    }

    @Override
    protected void onDestroy() {
        unregisterReceiver(packagesChanged);
        super.onDestroy();
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        // Android always pauses and resumes the activity around a new intent,
        // so onResume() refreshes the row once.
    }

    private boolean hasUsageAccess() {
        AppOpsManager ops = (AppOpsManager) getSystemService(APP_OPS_SERVICE);
        try {
            return ops != null && ops.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS,
                    Process.myUid(), getPackageName()) == AppOpsManager.MODE_ALLOWED;
        } catch (RuntimeException denied) { return false; }
    }

    private List<AppRanking.App> candidates(PackageManager pm) {
        Set<String> excluded = new HashSet<>(NOT_APPS);
        excluded.add(getPackageName());
        for (ResolveInfo ri : pm.queryIntentActivities(new Intent(Intent.ACTION_MAIN)
                .addCategory(Intent.CATEGORY_HOME), 0)) excluded.add(ri.activityInfo.packageName);

        Map<String, AppRanking.App> apps = new HashMap<>();
        for (String category : new String[] {Intent.CATEGORY_LEANBACK_LAUNCHER, Intent.CATEGORY_LAUNCHER}) {
            for (ResolveInfo ri : pm.queryIntentActivities(new Intent(Intent.ACTION_MAIN).addCategory(category), 0)) {
                String pkg = ri.activityInfo.packageName;
                if (excluded.contains(pkg) || apps.containsKey(pkg)
                        || !ri.activityInfo.applicationInfo.enabled || launchIntent(pm, pkg) == null) continue;
                apps.put(pkg, new AppRanking.App(pkg, pm.getApplicationLabel(ri.activityInfo.applicationInfo).toString()));
            }
        }
        return new ArrayList<>(apps.values());
    }

    private List<String> appList(PackageManager pm) {
        List<AppRanking.App> apps = candidates(pm);
        Map<String, AppRanking.App> byPackage = new HashMap<>();
        SharedPreferences prefs = getSharedPreferences(PREFS, 0);
        for (AppRanking.App app : apps) {
            byPackage.put(app.packageName, app);
            app.launches = prefs.getLong("launches." + app.packageName, 0);
            app.localLastUsed = prefs.getLong("last." + app.packageName, 0);
        }
        rankedByUsage = hasUsageAccess();
        if (rankedByUsage) {
            try {
                UsageStatsManager manager = (UsageStatsManager) getSystemService(USAGE_STATS_SERVICE);
                long now = System.currentTimeMillis();
                // Android keeps daily buckets for only about ten days. Aggregating lets it pick
                // weekly or monthly buckets that reach back the whole window, once per app.
                Map<String, UsageStats> stats = manager == null ? null
                        : manager.queryAndAggregateUsageStats(now - HISTORY_MILLIS, now);
                if (stats == null) rankedByUsage = false;
                else for (UsageStats stat : stats.values()) {
                    AppRanking.App app = byPackage.get(stat.getPackageName());
                    if (app == null) continue;
                    app.foregroundMillis += Math.max(0, stat.getTotalTimeInForeground());
                    app.lastUsed = Math.max(app.lastUsed, stat.getLastTimeUsed());
                }
            } catch (RuntimeException unavailable) { rankedByUsage = false; }
        }
        List<String> out = new ArrayList<>();
        for (AppRanking.App app : AppRanking.top(apps, rankedByUsage, PER_ROW)) out.add(app.packageName);
        return out;
    }

    @Override
    protected void onResume() {
        super.onResume();
        // Refresh usage and permissions whenever Home becomes visible again.
        buildTiles();
        View f = getCurrentFocus();
        if (f == null && !tiles.isEmpty()) tiles.get(0).requestFocus();
    }

    @Override
    public void onBackPressed() { /* home screen: nothing to go back to */ }

    // Static warm gradient, drawn once by the window: no extra view, no animation.
    private Drawable background() {
        GradientDrawable base = new GradientDrawable(GradientDrawable.Orientation.TL_BR,
                new int[] {0xFF20140E, 0xFF100B08, 0xFF050505});
        GradientDrawable warm = radial(0x566C3419, 0.03f, 0.02f, px(1300));
        for (GradientDrawable g : new GradientDrawable[] {base, warm}) g.setDither(true);
        return new LayerDrawable(new Drawable[] {base, warm});
    }

    private static GradientDrawable radial(int color, float cx, float cy, float r) {
        GradientDrawable g = new GradientDrawable();
        g.setGradientType(GradientDrawable.RADIAL_GRADIENT);
        g.setColors(new int[] {color, color & 0x00FFFFFF});
        g.setGradientCenter(cx, cy);
        g.setGradientRadius(r);
        return g;
    }

    private void buildTiles() {
        for (View t : tiles) root.removeView((View) t.getParent());
        tiles.clear();

        PackageManager pm = getPackageManager();
        int m = px(MARGIN), g = px(GAP), top1 = px(ROW1_TOP), top2 = px(ROW2_TOP);
        int w = (getResources().getDisplayMetrics().widthPixels - 2 * m - g * (PER_ROW - 1)) / PER_ROW;
        int h = w * 9 / 16;

        int col = 0;
        List<String> apps = appList(pm);
        rankingHint.setText(rankedByUsage ? "" : "For your most-used apps, enable Usage Access from All apps.");
        for (String pkg : apps) {
            Intent li = launchIntent(pm, pkg);
            if (li == null || col == PER_ROW) continue;
            Drawable banner = null;
            try {
                banner = pm.getActivityBanner(li);
                if (banner == null) banner = pm.getApplicationBanner(pkg);
            } catch (Exception ignored) {}
            String label = pkg;
            try { label = pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString(); } catch (Exception ignored) {}
            // Apps without a TV banner get a plain tile with their normal icon.
            Drawable icon = null;
            if (banner == null) try { icon = pm.getApplicationIcon(pkg); } catch (Exception ignored) {}
            addTile(pkg, label, banner, null, icon, m + col * (w + g), top1, w, h);
            col++;
        }

        int appCount = col;
        col = 0;
        if (!apps.contains(PLAY_STORE) && launchIntent(pm, PLAY_STORE) != null)
            addTile(PLAY_STORE, "Play Store", null, LineIcon.PLAY, null, m + col++ * (w + g), top2, w, h);
        // This Mi Box is connected to a TV; do not expose TV-input shortcuts here.
        // Hiding these buttons does not change any Android HDMI/input service.
        addTile(SETTINGS, "Settings", null, LineIcon.SETTINGS, null, m + col * (w + g), top2, w, h);
        col++;
        addTile(ALL_APPS, "All apps", null, LineIcon.APPS, null, m + col * (w + g), top2, w, h);

        linkFocus(appCount);

        View restore = null;
        for (View t : tiles) if (t.getTag().equals(focusedKey)) restore = t;
        if (restore != null) restore.requestFocus();
        else if (!tiles.isEmpty()) tiles.get(0).requestFocus();
    }

    // Explicit links avoid focus jumping unpredictably between unequal row lengths.
    private void linkFocus(int appCount) {
        int utilityCount = tiles.size() - appCount;
        for (int i = 0; i < tiles.size(); i++) {
            View tile = tiles.get(i);
            boolean top = i < appCount;
            int start = top ? 0 : appCount;
            int count = top ? appCount : utilityCount;
            int column = i - start;
            tile.setNextFocusLeftId(tiles.get(start + Math.max(0, column - 1)).getId());
            tile.setNextFocusRightId(tiles.get(start + Math.min(count - 1, column + 1)).getId());
            tile.setNextFocusUpId(top || appCount == 0 ? tile.getId()
                    : tiles.get(Math.min(column, appCount - 1)).getId());
            tile.setNextFocusDownId(!top || utilityCount == 0 ? tile.getId()
                    : tiles.get(appCount + Math.min(column, utilityCount - 1)).getId());
        }
    }

    private void addTile(final String key, String label, Drawable banner, int[] lineIcon, Drawable appIcon,
                         int x, int y, int w, int h) {
        FrameLayout card = new FrameLayout(this);
        final GradientDrawable bg = new GradientDrawable();
        bg.setCornerRadius(px(RADIUS));
        if (banner != null) {
            bg.setColor(0xFF1E1A1C);
            ImageView iv = new ImageView(this);
            iv.setImageDrawable(fit(banner, w, h));
            card.addView(iv, new FrameLayout.LayoutParams(-1, -1));
        } else {
            // Quiet "glass" tile: icon above label.
            bg.setColor(0x13FFFFFF);
            bg.setStroke(Math.max(1, px(2)), 0x17FFFFFF);
            LinearLayout inner = new LinearLayout(this);
            inner.setOrientation(LinearLayout.VERTICAL);
            inner.setGravity(Gravity.CENTER);
            ImageView iv = new ImageView(this);
            int size = lineIcon != null ? px(44) : px(64);
            if (lineIcon != null) iv.setImageDrawable(new LineIcon(lineIcon));
            else if (appIcon != null) iv.setImageDrawable(fit(appIcon, size, size));
            inner.addView(iv, new LinearLayout.LayoutParams(size, size));
            TextView t = text(px(24), 0xE0FFFFFF, regular);
            t.setText(label);
            t.setSingleLine(true);
            t.setEllipsize(android.text.TextUtils.TruncateAt.END);
            t.setGravity(Gravity.CENTER);
            t.setPadding(px(16), 0, px(16), 0);
            LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(-2, -2);
            lp.topMargin = px(12);
            inner.addView(t, lp);
            card.addView(inner, new FrameLayout.LayoutParams(-1, -1));
        }
        card.setBackground(bg);
        card.setClipToOutline(true);
        card.setFocusable(true);
        card.setId(View.generateViewId());
        card.setTag(key);
        card.setContentDescription(label);

        // Banner tiles show their name underneath when focused.
        final TextView caption = banner == null ? null : text(px(24), Color.WHITE, regular);
        if (caption != null) {
            caption.setText(label);
            caption.setSingleLine(true);
            caption.setEllipsize(android.text.TextUtils.TruncateAt.END);
            caption.setGravity(Gravity.CENTER_HORIZONTAL);
            caption.setVisibility(View.INVISIBLE);
        }

        final boolean glass = banner == null;
        card.setOnFocusChangeListener((v, has) -> {
            if (has) focusedKey = key;
            if (glass) bg.setColor(has ? 0x38FFFFFF : 0x13FFFFFF);
            // Instant focus feedback respects the user's preference for no animations.
            v.setScaleX(has ? 1.06f : 1f);
            v.setScaleY(has ? 1.06f : 1f);
            v.setTranslationZ(has ? px(18) : 0);
            if (caption != null) caption.setVisibility(has ? View.VISIBLE : View.INVISIBLE);
        });
        card.setOnClickListener(v -> open(key));
        card.setOnKeyListener((v, code, ev) -> {
            if (ev.getAction() == KeyEvent.ACTION_UP && (code == KeyEvent.KEYCODE_DPAD_CENTER
                    || code == KeyEvent.KEYCODE_ENTER || code == KeyEvent.KEYCODE_NUMPAD_ENTER)) {
                open(key);
                return true;
            }
            return false;
        });

        FrameLayout wrap = new FrameLayout(this);
        wrap.setClipChildren(false);
        wrap.addView(card, new FrameLayout.LayoutParams(w, h));
        if (caption != null) {
            FrameLayout.LayoutParams cp = new FrameLayout.LayoutParams(w, -2);
            cp.topMargin = h + px(22);
            wrap.addView(caption, cp);
        }
        root.addView(wrap, at(x, y, w, -2));
        tiles.add(card);
    }

    private void open(String key) {
        if (ALL_APPS.equals(key)) { showAllApps(); return; }
        Intent i;
        if (SETTINGS.equals(key)) {
            i = new Intent(Settings.ACTION_SETTINGS);
        } else {
            i = launchIntent(getPackageManager(), key);
            if (i == null) return;
        }
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        try {
            startActivity(i);
            if (!SETTINGS.equals(key) && !PLAY_STORE.equals(key)) {
                SharedPreferences prefs = getSharedPreferences(PREFS, 0);
                long previous = prefs.getLong("launches." + key, 0);
                prefs.edit().putLong("launches." + key, previous == Long.MAX_VALUE ? previous : previous + 1)
                        .putLong("last." + key, System.currentTimeMillis()).apply();
            }
        }
        catch (Exception ignored) {
            Toast.makeText(this, "Unable to open this app. Check Android Settings.", Toast.LENGTH_SHORT).show();
        }
    }

    private void showAllApps() {
        List<AppRanking.App> apps = candidates(getPackageManager());
        Collections.sort(apps, (a, b) -> {
            int label = a.label.compareToIgnoreCase(b.label);
            return label != 0 ? label : a.packageName.compareTo(b.packageName);
        });
        String[] labels = new String[apps.size()];
        for (int i = 0; i < labels.length; i++) labels[i] = apps.get(i).label;
        new AlertDialog.Builder(this).setTitle("All apps")
                .setItems(labels, (dialog, which) -> open(apps.get(which).packageName))
                .setNeutralButton("Usage access", (dialog, which) -> showUsageAccess())
                .setNegativeButton("Close", null).show();
    }

    private void showUsageAccess() {
        new AlertDialog.Builder(this).setTitle("Show your most-used apps")
                .setMessage("Usage Access lets Calm Home rank apps by time used on this TV over the last 30 days. "
                        + "Nothing is sent online. You can revoke this access in Android Settings. "
                        + "Without it, the row uses launches from Calm Home, then alphabetical order when there is no history.")
                .setPositiveButton("Open settings", (dialog, which) -> {
                    Intent intent = new Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS,
                            Uri.parse("package:" + getPackageName()));
                    try { startActivity(intent); }
                    catch (RuntimeException missingDetail) {
                        try { startActivity(new Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)); }
                        catch (RuntimeException unavailable) {
                            Toast.makeText(this, "This TV needs the computer setup installer to enable Usage Access.", Toast.LENGTH_LONG).show();
                        }
                    }
                }).setNegativeButton("Cancel", null).show();
    }

    private static Intent launchIntent(PackageManager pm, String pkg) {
        Intent i = pm.getLeanbackLaunchIntentForPackage(pkg);
        return i != null ? i : pm.getLaunchIntentForPackage(pkg);
    }

    // Xiaomi TVs ship MiLan Pro but don't register it by name; every other TV gets Roboto.
    private static void loadFonts() {
        if (regular != null) return;
        regular = fromFile("/system/fonts/MILanPro_Normal.ttf", Typeface.create("sans-serif", Typeface.NORMAL));
        semibold = fromFile("/system/fonts/MILanPro_SemiBold.ttf", Typeface.create("sans-serif-medium", Typeface.NORMAL));
    }

    private static Typeface fromFile(String path, Typeface fallback) {
        try { return new File(path).exists() ? Typeface.createFromFile(path) : fallback; }
        catch (Exception e) { return fallback; }
    }

    // Draws a banner once into a tile-sized bitmap (center-cropped). Some apps ship huge banners
    // that Android 9 refuses to draw ("Canvas: trying to draw too large bitmap"); this also saves RAM.
    private Drawable fit(Drawable d, int w, int h) {
        try {
            Bitmap b = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888);
            int iw = d.getIntrinsicWidth(), ih = d.getIntrinsicHeight();
            if (iw <= 0 || ih <= 0) { iw = w; ih = h; }
            float s = Math.max((float) w / iw, (float) h / ih);
            int dw = Math.round(iw * s), dh = Math.round(ih * s);
            d.setBounds((w - dw) / 2, (h - dh) / 2, (w - dw) / 2 + dw, (h - dh) / 2 + dh);
            d.draw(new Canvas(b));
            return new BitmapDrawable(getResources(), b);
        } catch (Throwable t) {
            // Never return an oversized bitmap to Android 9 after a failed resize.
            return new ColorDrawable(0xFF28201A);
        }
    }

    private int px(int v) {
        return Math.round(v * scale);
    }

    private TextClock clock(String f12, String f24, int px, int color, Typeface tf) {
        TextClock c = new TextClock(this);
        c.setFormat12Hour(f12);
        c.setFormat24Hour(f24);
        c.setTextSize(TypedValue.COMPLEX_UNIT_PX, px);
        c.setTextColor(color);
        c.setTypeface(tf);
        return c;
    }

    private TextView text(int px, int color, Typeface tf) {
        TextView t = new TextView(this);
        t.setTextSize(TypedValue.COMPLEX_UNIT_PX, px);
        t.setTextColor(color);
        if (tf != null) t.setTypeface(tf);
        return t;
    }

    private static FrameLayout.LayoutParams at(int x, int y, int w, int h) {
        FrameLayout.LayoutParams lp = new FrameLayout.LayoutParams(w, h);
        lp.leftMargin = x;
        lp.topMargin = y;
        return lp;
    }
}
