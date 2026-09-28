import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

export interface DebugAppRow {
  bundleName: string;
  appName: string;
  installTime: number;
  certEndTime: number;
  lastTarget: string;
  remarks: string;
}

export interface HistoryRow {
  id: number;
  bundleName: string;
  target: string;
  hapPath: string;
  startedAt: number;
  finishedAt: number;
  status: string;
  errorText: string;
  logPath: string;
}

const DB_NAME: string = 'hapkit.db';
const SCHEMA: string =
  'CREATE TABLE IF NOT EXISTS debug_app (' +
  'bundle_name TEXT PRIMARY KEY, app_name TEXT, icon_path TEXT, install_time INTEGER, ' +
  'cert_end_time INTEGER, can_re_install INTEGER, is_game INTEGER, last_target TEXT, remarks TEXT, ' +
  'updated_at INTEGER);';
const SCHEMA_HIST: string =
  'CREATE TABLE IF NOT EXISTS debug_history (' +
  'id INTEGER PRIMARY KEY AUTOINCREMENT, bundle_name TEXT, target TEXT, hap_path TEXT, ' +
  'started_at INTEGER, finished_at INTEGER, status TEXT, error_text TEXT, log_path TEXT);';

export class Store {
  private static rdb: relationalStore.RdbStore | null = null;

  static async init(context: common.UIAbilityContext): Promise<void> {
    if (Store.rdb !== null) {
      return;
    }
    const config: relationalStore.StoreConfig = {
      name: DB_NAME,
      securityLevel: relationalStore.SecurityLevel.S1
    };
    Store.rdb = await relationalStore.getRdbStore(context, config);
    await Store.rdb.executeSql(SCHEMA);
    await Store.rdb.executeSql(SCHEMA_HIST);
    hilog.info(0x0000, 'HAPKIT', '%{public}s', '[store] hapkit.db ready');
  }

  static async insertHistory(bundleName: string, target: string, hapPath: string,
    status: string, logPath: string): Promise<number> {
    if (Store.rdb === null) {
      return -1;
    }
    const bucket: relationalStore.ValuesBucket = {
      'bundle_name': bundleName,
      'target': target,
      'hap_path': hapPath,
      'started_at': Date.now(),
      'finished_at': 0,
      'status': status,
      'error_text': '',
      'log_path': logPath
    };
    const rowId: number = await Store.rdb.insert('debug_history', bucket);
    return rowId;
  }

  static async updateHistory(id: number, status: string, errorText: string): Promise<void> {
    if (Store.rdb === null || id < 0) {
      return;
    }
    const bucket: relationalStore.ValuesBucket = {
      'status': status,
      'finished_at': Date.now(),
      'error_text': errorText
    };
    const pred: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('debug_history');
    pred.equalTo('id', id);
    await Store.rdb.update(bucket, pred);
  }

  static async pendingKilled(): Promise<HistoryRow[]> {
    if (Store.rdb === null) {
      return [];
    }
    const pred: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('debug_history');
    pred.equalTo('status', 'killed_expected');
    const rs: relationalStore.ResultSet = await Store.rdb.query(pred);
    const out: HistoryRow[] = [];
    while (rs.goToNextRow()) {
      out.push(Store.rowOf(rs));
    }
    rs.close();
    return out;
  }

  static async listHistory(limit: number): Promise<HistoryRow[]> {
    if (Store.rdb === null) {
      return [];
    }
    const sql: string = 'SELECT * FROM debug_history ORDER BY id DESC LIMIT ' + limit.toString();
    const rs: relationalStore.ResultSet = await Store.rdb.querySql(sql);
    const out: HistoryRow[] = [];
    while (rs.goToNextRow()) {
      out.push(Store.rowOf(rs));
    }
    rs.close();
    return out;
  }

  private static rowOf(rs: relationalStore.ResultSet): HistoryRow {
    return {
      id: rs.getLong(rs.getColumnIndex('id')),
      bundleName: rs.getString(rs.getColumnIndex('bundle_name')),
      target: rs.getString(rs.getColumnIndex('target')),
      hapPath: rs.getString(rs.getColumnIndex('hap_path')),
      startedAt: rs.getLong(rs.getColumnIndex('started_at')),
      finishedAt: rs.getLong(rs.getColumnIndex('finished_at')),
      status: rs.getString(rs.getColumnIndex('status')),
      errorText: rs.getString(rs.getColumnIndex('error_text')),
      logPath: rs.getString(rs.getColumnIndex('log_path'))
    };
  }

  static async upsertDebugApp(row: DebugAppRow): Promise<void> {
    if (Store.rdb === null) {
      return;
    }
    const bucket: relationalStore.ValuesBucket = {
      'bundle_name': row.bundleName,
      'app_name': row.appName,
      'install_time': row.installTime,
      'cert_end_time': row.certEndTime,
      'last_target': row.lastTarget,
      'remarks': row.remarks,
      'updated_at': Date.now()
    };
    const pred: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('debug_app');
    pred.equalTo('bundle_name', row.bundleName);
    const updated: number = await Store.rdb.update(bucket, pred);
    if (updated === 0) {
      await Store.rdb.insert('debug_app', bucket);
    }
  }

  /**
   * 冷启调用：把上次装机遗留的 killed_expected 行改判。
   * 判定依据：hapkit.log 是否含 "install bundle successfully"。
   */
  static async repairKilled(context: common.UIAbilityContext): Promise<number> {
    const rows: HistoryRow[] = await Store.pendingKilled();
    if (rows.length === 0) {
      return 0;
    }
    let logText: string = '';
    try {
      logText = fileIo.readTextSync(context.filesDir + '/hapkit.log');
    } catch (ignored) {
    }
    const success: boolean = logText.indexOf('install bundle successfully') >= 0;
    for (const r of rows) {
      await Store.updateHistory(r.id, success ? 'success' : 'failed',
        success ? '' : 'no success marker in hapkit.log');
    }
    hilog.info(0x0000, 'HAPKIT', '%{public}s',
      '[store] repaired ' + rows.length.toString() + ' killed_expected rows, ok=' + success);
    return rows.length;
  }
}
