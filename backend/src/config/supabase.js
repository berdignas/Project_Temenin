// backend/src/config/supabase.js

// Polyfill WebSocket globally for Node.js < 22 Supabase compatibility
try {
  global.WebSocket = require('ws');
} catch (e) {
  console.warn('⚠️ ws package is not installed/loaded:', e.message);
}

const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseAnonKey = process.env.SUPABASE_ANON_KEY;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

// Client admin untuk operasi backend (bypass RLS)
const supabaseAdmin = createClient(
  supabaseUrl,
  supabaseServiceKey,
  {
    auth: {
      persistSession: false
    }
  }
);

// Client untuk operasi umum (gunakan supabaseAdmin agar tidak terblokir RLS di backend)
const supabase = supabaseAdmin;

// 🔴 Fungsi query wrapper kompatibilitas SQL dengan Supabase PostgREST
const query = async (text, params = []) => {
  try {
    if (!text || typeof text !== 'string') {
      throw new Error('Query text must be a valid SQL string');
    }

    const cleanText = text.trim();
    const upperText = cleanText.toUpperCase();
    const cleanParams = Array.isArray(params) ? params : [];

    const getParamValue = (indexStr) => {
      const idx = parseInt(indexStr, 10) - 1;
      return cleanParams[idx];
    };

    const cleanTableName = (rawTable) => {
      if (!rawTable) return null;
      let tbl = rawTable.trim().replace(/["'`]/g, '');
      if (tbl.toLowerCase().startsWith('public.')) {
        tbl = tbl.substring(7);
      }
      return tbl;
    };

    const parseValue = (token) => {
      if (!token) return null;
      const t = token.trim();
      const pMatch = t.match(/^\$(\d+)$/);
      if (pMatch) return getParamValue(pMatch[1]);
      if ((t.startsWith("'") && t.endsWith("'")) || (t.startsWith('"') && t.endsWith('"'))) {
        return t.slice(1, -1);
      }
      if (t.toUpperCase() === 'NULL') return null;
      if (t.toUpperCase() === 'TRUE') return true;
      if (t.toUpperCase() === 'FALSE') return false;
      if (!isNaN(Number(t))) return Number(t);
      return t;
    };

    const formatPostgrestOrFilter = (cond) => {
      const trimmed = cond.trim().replace(/^\(|\)$/g, '');
      const m = trimmed.match(/^([a-zA-Z0-9_.]+)\s*(=|!=|<>|>|>=|<|<=|LIKE|ILIKE)\s*(.+)$/i);
      if (m) {
        const col = m[1].replace(/^[a-zA-Z0-9_]+\./, '').replace(/["'`]/g, '');
        const opRaw = m[2].toUpperCase();
        let op = 'eq';
        if (opRaw === '!=' || opRaw === '<>') op = 'neq';
        else if (opRaw === '>') op = 'gt';
        else if (opRaw === '>=') op = 'gte';
        else if (opRaw === '<') op = 'lt';
        else if (opRaw === '<=') op = 'lte';
        else if (opRaw === 'LIKE') op = 'like';
        else if (opRaw === 'ILIKE') op = 'ilike';

        const val = parseValue(m[3]);
        return `${col}.${op}.${val}`;
      }
      return null;
    };

    // Helper: Parse WHERE conditions dynamically without silent drops
    const applyWhereConditions = (queryBuilder, whereClause) => {
      if (!whereClause || !whereClause.trim()) {
        return { builder: queryBuilder, count: 0 };
      }

      // Pre-extract BETWEEN ... AND ... to prevent incorrect splitting on AND
      const betweens = [];
      const processed = whereClause.replace(
        /([a-zA-Z0-9_.]+)\s+BETWEEN\s+(\$?\w+|'[^']*'|"[^"]*")\s+AND\s+(\$?\w+|'[^']*'|"[^"]*")/gi,
        (match, col, v1, v2) => {
          betweens.push({ col, v1, v2 });
          return `__BETWEEN_${betweens.length - 1}__`;
        }
      );

      let count = 0;
      const conditions = processed.split(/\s+AND\s+/i);

      for (const cond of conditions) {
        const trimmed = cond.trim();

        // 1. Placeholder for BETWEEN
        const bMatch = trimmed.match(/^__BETWEEN_(\d+)__$/);
        if (bMatch) {
          const item = betweens[parseInt(bMatch[1], 10)];
          const col = item.col.replace(/^[a-zA-Z0-9_]+\./, '').replace(/["'`]/g, '');
          const val1 = parseValue(item.v1);
          const val2 = parseValue(item.v2);
          queryBuilder = queryBuilder.gte(col, val1).lte(col, val2);
          count++;
          continue;
        }

        // 2. OR expression (e.g. status = 'pending' OR status = 'ongoing')
        if (/\s+OR\s+/i.test(trimmed)) {
          const orParts = trimmed.replace(/^\(|\)$/g, '').split(/\s+OR\s+/i);
          const converted = orParts.map(p => formatPostgrestOrFilter(p));
          if (converted.every(Boolean)) {
            queryBuilder = queryBuilder.or(converted.join(','));
            count++;
            continue;
          } else {
            throw new Error(`[Supabase Query Parser Error] Could not safely convert OR sub-condition: "${trimmed}"`);
          }
        }

        // 3. IS NULL
        const isNullMatch = trimmed.match(/^([a-zA-Z0-9_.]+)\s+IS\s+NULL$/i);
        if (isNullMatch) {
          const col = isNullMatch[1].replace(/^[a-zA-Z0-9_]+\./, '').replace(/["'`]/g, '');
          queryBuilder = queryBuilder.is(col, null);
          count++;
          continue;
        }

        // 4. IS NOT NULL
        const notNullMatch = trimmed.match(/^([a-zA-Z0-9_.]+)\s+IS\s+NOT\s+NULL$/i);
        if (notNullMatch) {
          const col = notNullMatch[1].replace(/^[a-zA-Z0-9_]+\./, '').replace(/["'`]/g, '');
          queryBuilder = queryBuilder.not(col, 'is', null);
          count++;
          continue;
        }

        // 5. NOT IN (...)
        const notInMatch = trimmed.match(/^([a-zA-Z0-9_.]+)\s+NOT\s+IN\s*\(([^)]+)\)$/i);
        if (notInMatch) {
          const col = notInMatch[1].replace(/^[a-zA-Z0-9_]+\./, '').replace(/["'`]/g, '');
          const rawItems = notInMatch[2].split(',').map(s => parseValue(s));
          const valArray = rawItems.length === 1 && Array.isArray(rawItems[0]) ? rawItems[0] : rawItems;
          queryBuilder = queryBuilder.not(col, 'in', valArray);
          count++;
          continue;
        }

        // 6. IN (...)
        const inMatch = trimmed.match(/^([a-zA-Z0-9_.]+)\s+IN\s*\(([^)]+)\)$/i);
        if (inMatch) {
          const col = inMatch[1].replace(/^[a-zA-Z0-9_]+\./, '').replace(/["'`]/g, '');
          const rawItems = inMatch[2].split(',').map(s => parseValue(s));
          const valArray = rawItems.length === 1 && Array.isArray(rawItems[0]) ? rawItems[0] : rawItems;
          queryBuilder = queryBuilder.in(col, valArray);
          count++;
          continue;
        }

        // 7. General Operators: >=, <=, !=, <>, >, <, =, ILIKE, LIKE
        const opMatch = trimmed.match(/^([a-zA-Z0-9_.]+)\s*(>=|<=|!=|<>|>|<|=|ILIKE|LIKE)\s*(.+)$/i);
        if (opMatch) {
          const col = opMatch[1].replace(/^[a-zA-Z0-9_]+\./, '').replace(/["'`]/g, '');
          const op = opMatch[2].toUpperCase();
          const val = parseValue(opMatch[3]);

          if (op === '=') queryBuilder = queryBuilder.eq(col, val);
          else if (op === '!=' || op === '<>') queryBuilder = queryBuilder.neq(col, val);
          else if (op === '>') queryBuilder = queryBuilder.gt(col, val);
          else if (op === '>=') queryBuilder = queryBuilder.gte(col, val);
          else if (op === '<') queryBuilder = queryBuilder.lt(col, val);
          else if (op === '<=') queryBuilder = queryBuilder.lte(col, val);
          else if (op === 'LIKE') queryBuilder = queryBuilder.like(col, val);
          else if (op === 'ILIKE') queryBuilder = queryBuilder.ilike(col, val);

          count++;
          continue;
        }

        // 8. 🛡️ FAIL-SAFE DEFENSE: Never silently drop unsupported WHERE conditions
        throw new Error(`[Supabase Query Parser Error] Unrecognized or unsupported WHERE clause condition: "${trimmed}". Aborting query to prevent data corruption or unfiltered execution.`);
      }

      return { builder: queryBuilder, count };
    };

    // 1. SELECT queries
    if (upperText.startsWith('SELECT')) {
      const selectMatch = cleanText.match(/^SELECT\s+([\s\S]+?)\s+FROM\s+([a-zA-Z0-9_."]+)/i);
      if (!selectMatch) {
        throw new Error(`Could not parse SELECT query: ${cleanText}`);
      }
      const rawCols = selectMatch[1].trim();
      const tableName = cleanTableName(selectMatch[2]);
      if (!tableName) {
        throw new Error(`Could not determine table name from SELECT query: ${cleanText}`);
      }

      const isCountOnly = /^COUNT\s*\(\s*\*\s*\)$/i.test(rawCols);
      const selectProjection = isCountOnly ? '*' : (rawCols && rawCols !== '*' ? rawCols.replace(/\s+/g, ' ') : '*');

      let supabaseQuery = isCountOnly
        ? supabaseAdmin.from(tableName).select('*', { count: 'exact', head: true })
        : supabaseAdmin.from(tableName).select(selectProjection);

      const whereMatch = cleanText.match(/WHERE\s+([\s\S]+?)(?:\s+ORDER\s+BY|\s+LIMIT|\s+OFFSET|$)/i);
      if (whereMatch) {
        const { builder } = applyWhereConditions(supabaseQuery, whereMatch[1]);
        supabaseQuery = builder;
      }

      const orderMatch = cleanText.match(/ORDER\s+BY\s+([a-zA-Z0-9_.]+)(?:\s+(ASC|DESC))?/i);
      if (orderMatch) {
        const col = orderMatch[1].replace(/^[a-zA-Z0-9_]+\./, '');
        const isAsc = (orderMatch[2] || 'ASC').toUpperCase() === 'ASC';
        supabaseQuery = supabaseQuery.order(col, { ascending: isAsc });
      }

      const limitMatch = cleanText.match(/LIMIT\s+(\d+)/i);
      if (limitMatch) {
        supabaseQuery = supabaseQuery.limit(parseInt(limitMatch[1], 10));
      }

      const { data, count, error } = await supabaseQuery;
      if (error) throw error;

      if (isCountOnly) {
        return { rows: [{ count: count || 0 }], rowCount: 1, count: count || 0 };
      }

      return { rows: data || [], rowCount: data ? data.length : 0 };
    }

    // 2. UPDATE queries
    if (upperText.startsWith('UPDATE')) {
      const tableMatch = cleanText.match(/UPDATE\s+([a-zA-Z0-9_."]+)/i);
      const tableName = cleanTableName(tableMatch ? tableMatch[1] : null);
      if (!tableName) {
        throw new Error(`Could not determine table name from UPDATE query: ${cleanText}`);
      }

      const setMatch = cleanText.match(/SET\s+([\s\S]+?)(?:\s+WHERE|$)/i);
      if (!setMatch) {
        throw new Error(`Could not parse SET clause in UPDATE query: ${cleanText}`);
      }

      const rawSetClause = setMatch[1].trim();
      const updates = {};

      // Parse comma-separated SET assignments: col = $N, col2 = 'val', etc.
      const setParts = rawSetClause.split(/,(?![^(]*\))/);
      for (const part of setParts) {
        const paramAssign = part.trim().match(/^([a-zA-Z0-9_.]+)\s*=\s*\$(\d+)$/i);
        if (paramAssign) {
          const col = paramAssign[1].replace(/^[a-zA-Z0-9_]+\./, '').replace(/["'`]/g, '');
          updates[col] = getParamValue(paramAssign[2]);
          continue;
        }
        const litAssign = part.trim().match(/^([a-zA-Z0-9_.]+)\s*=\s*['"]([^'"]*)['"]$/i);
        if (litAssign) {
          const col = litAssign[1].replace(/^[a-zA-Z0-9_]+\./, '').replace(/["'`]/g, '');
          updates[col] = litAssign[2];
          continue;
        }
        const nowAssign = part.trim().match(/^([a-zA-Z0-9_.]+)\s*=\s*(?:NOW\(\)|CURRENT_TIMESTAMP)/i);
        if (nowAssign) {
          const col = nowAssign[1].replace(/^[a-zA-Z0-9_]+\./, '').replace(/["'`]/g, '');
          updates[col] = new Date().toISOString();
          continue;
        }
      }

      if (Object.keys(updates).length === 0) {
        throw new Error(`No valid column assignments found in SET clause: ${rawSetClause}`);
      }

      // Guard: Ensure UPDATE has a valid WHERE clause to prevent catastrophic full-table overwrites
      const whereMatch = cleanText.match(/WHERE\s+([\s\S]+?)$/i);
      if (!whereMatch) {
        throw new Error(`Refusing to execute UPDATE without a WHERE clause to prevent data corruption: ${cleanText}`);
      }

      let supabaseQuery = supabaseAdmin.from(tableName).update(updates);
      const { builder, count } = applyWhereConditions(supabaseQuery, whereMatch[1]);
      if (count === 0) {
        throw new Error(`No valid WHERE condition could be extracted from: ${whereMatch[1]}`);
      }

      const { data, error } = await builder.select();
      if (error) throw error;
      return { rows: data || [], rowCount: data ? data.length : 0 };
    }

    // 3. INSERT queries
    if (upperText.startsWith('INSERT')) {
      const match = cleanText.match(/INSERT\s+INTO\s+([a-zA-Z0-9_."]+)\s*\(([^)]+)\)\s*VALUES\s*\(([^)]+)\)/i);
      if (!match) {
        throw new Error(`Could not parse INSERT query format: ${cleanText}`);
      }

      const tableName = cleanTableName(match[1]);
      const columns = match[2].split(',').map(c => c.trim().replace(/["'`]/g, ''));
      const rawValues = match[3].split(',').map(v => v.trim());

      if (columns.length !== rawValues.length) {
        throw new Error(`Column count (${columns.length}) does not match value count (${rawValues.length})`);
      }

      const payload = {};
      for (let i = 0; i < columns.length; i++) {
        const col = columns[i];
        const valToken = rawValues[i];
        const paramMatch = valToken.match(/^\$(\d+)$/);
        if (paramMatch) {
          payload[col] = getParamValue(paramMatch[1]);
        } else if (valToken.startsWith("'") && valToken.endsWith("'")) {
          payload[col] = valToken.slice(1, -1);
        } else if (valToken.toUpperCase() === 'NULL') {
          payload[col] = null;
        } else if (!isNaN(Number(valToken))) {
          payload[col] = Number(valToken);
        } else {
          payload[col] = valToken;
        }
      }

      const { data, error } = await supabaseAdmin.from(tableName).insert(payload).select();
      if (error) throw error;
      return { rows: data || [], rowCount: data ? data.length : 0 };
    }

    // 4. DELETE queries
    if (upperText.startsWith('DELETE')) {
      const tableMatch = cleanText.match(/DELETE\s+FROM\s+([a-zA-Z0-9_."]+)/i);
      const tableName = cleanTableName(tableMatch ? tableMatch[1] : null);
      if (!tableName) {
        throw new Error(`Could not determine table name from DELETE query: ${cleanText}`);
      }

      const whereMatch = cleanText.match(/WHERE\s+([\s\S]+?)$/i);
      if (!whereMatch) {
        throw new Error(`Refusing to execute DELETE without a WHERE clause to prevent accidental table truncation: ${cleanText}`);
      }

      let supabaseQuery = supabaseAdmin.from(tableName).delete();
      const { builder, count } = applyWhereConditions(supabaseQuery, whereMatch[1]);
      if (count === 0) {
        throw new Error(`No valid WHERE condition could be extracted from: ${whereMatch[1]}`);
      }

      const { data, error } = await builder.select();
      if (error) throw error;
      return { rows: data || [], rowCount: data ? data.length : 0 };
    }

    throw new Error(`Query type not supported in wrapper: ${cleanText.substring(0, 30)}...`);
  } catch (error) {
    console.error('❌ [Supabase Query Wrapper Error]:', error.message, { text, params });
    throw error;
  }
};

module.exports = {
  supabase,
  supabaseAdmin,
  query 
};