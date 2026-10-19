package com.luisbadalo.calmhome;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/** Pure ranking policy, independent of Android permissions and UI. */
final class AppRanking {
    static final class App {
        final String packageName;
        final String label;
        long foregroundMillis, lastUsed, launches, localLastUsed;

        App(String packageName, String label) {
            this.packageName = packageName;
            this.label = label;
        }
    }

    static List<App> top(List<App> candidates, boolean usageAvailable, int limit) {
        List<App> sorted = new ArrayList<>(candidates);
        Collections.sort(sorted, (a, b) -> {
            int order;
            if (usageAvailable) {
                order = Long.compare(b.foregroundMillis, a.foregroundMillis);
                if (order != 0) return order;
                order = Long.compare(b.lastUsed, a.lastUsed);
                if (order != 0) return order;
            }
            order = Long.compare(b.launches, a.launches);
            if (order != 0) return order;
            order = Long.compare(b.localLastUsed, a.localLastUsed);
            if (order != 0) return order;
            order = a.label.compareToIgnoreCase(b.label);
            return order != 0 ? order : a.packageName.compareTo(b.packageName);
        });
        return new ArrayList<>(sorted.subList(0, Math.min(Math.max(0, limit), sorted.size())));
    }
}
