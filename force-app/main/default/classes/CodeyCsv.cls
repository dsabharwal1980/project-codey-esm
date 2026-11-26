/** Small CSV reader/writer for Codey bulk member files (quotes, commas and new lines inside quotes, BOM). */
public with sharing class CodeyCsv {

    public static final Map<String, String> HEADER_ALIASES = new Map<String, String>{
        'name' => 'name', 'site' => 'name', 'site name' => 'name', 'sitename' => 'name', 'location' => 'name', 'location name' => 'name', 'member' => 'name',
        'street' => 'street', 'address' => 'street', 'address1' => 'street', 'address line 1' => 'street', 'street address' => 'street', 'streetaddress' => 'street',
        'city' => 'city', 'town' => 'city', 'locality' => 'city',
        'state' => 'state', 'region' => 'state', 'county' => 'state', 'province' => 'state',
        'zip' => 'postal', 'zipcode' => 'postal', 'zip code' => 'postal', 'postal' => 'postal', 'postal code' => 'postal', 'postalcode' => 'postal', 'postcode' => 'postal',
        'country' => 'country', 'country code' => 'country', 'countrycode' => 'country' };

    public static List<List<String>> parse(String text) {
        List<List<String>> rows = new List<List<String>>();
        if (String.isBlank(text)) return rows;
        String s = text.removeStart('\uFEFF').replace('\r\n', '\n').replace('\r', '\n');
        String firstLine = s.substringBefore('\n');
        String delim = firstLine.contains(',') ? ',' : (firstLine.contains(';') ? ';' : (firstLine.contains('\t') ? '\t' : ','));
        if (!s.contains('"')) {
            // fast path: no quoted fields
            for (String ln : s.split('\n')) {
                List<String> row = new List<String>();
                for (String v : ln.split(delim == '\t' ? '\t' : (delim == ';' ? ';' : ','), -1)) row.add(v.trim());
                if (!isEmptyRow(row)) rows.add(row);
            }
            return rows;
        }
        List<String> chars = s.split('');
        List<String> row = new List<String>();
        List<String> field = new List<String>();
        Boolean inQuotes = false;
        Integer n = chars.size();
        for (Integer i = 0; i < n; i++) {
            String c = chars[i];
            if (inQuotes) {
                if (c == '"') {
                    if (i + 1 < n && chars[i + 1] == '"') { field.add('"'); i++; }
                    else inQuotes = false;
                } else field.add(c);
            } else if (c == '"') inQuotes = true;
            else if (c == delim) { row.add(String.join(field, '').trim()); field = new List<String>(); }
            else if (c == '\n') { row.add(String.join(field, '').trim()); field = new List<String>(); if (!isEmptyRow(row)) rows.add(row); row = new List<String>(); }
            else field.add(c);
        }
        row.add(String.join(field, '').trim());
        if (!isEmptyRow(row)) rows.add(row);
        return rows;
    }

    static Boolean isEmptyRow(List<String> r) { for (String v : r) if (String.isNotBlank(v)) return false; return true; }

    /** Maps the header row to canonical columns (name, street, city, state, postal, country). */
    public static Map<String, Integer> mapHeader(List<String> header) {
        Map<String, Integer> out = new Map<String, Integer>();
        for (Integer i = 0; i < header.size(); i++) {
            String h = header[i].toLowerCase().replaceAll('[_\\-]', ' ').replaceAll('\\s+', ' ').trim();
            if (HEADER_ALIASES.containsKey(h) && !out.containsKey(HEADER_ALIASES.get(h))) out.put(HEADER_ALIASES.get(h), i);
        }
        return out;
    }

    public static String esc(Object v) {
        String s = v == null ? '' : String.valueOf(v);
        if (s.contains(',') || s.contains('"') || s.contains('\n')) s = '"' + s.replace('"', '""') + '"';
        return s;
    }

    public static String line(List<Object> values) {
        List<String> out = new List<String>();
        for (Object v : values) out.add(esc(v));
        return String.join(out, ',');
    }
}
