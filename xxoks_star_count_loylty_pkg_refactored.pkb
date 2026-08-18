/* Perforce $File: <path/file.ext> $ */
/* Perforce $Revision: <rev> $ $DateTime: <yyyy/mm/dd hh:mi:ss> $ */
-------------------------------------------------------------------------------
-- Script Name        :  xxoks_star_count_loylty_pkg.pkb
-- Object Name        :  XXOKS_STAR_COUNT_LOYLTY_PKG
-- Description        :  Package for loading the star count allocation data
-- Refactored Version  :  Improved code quality, eliminated duplication
-------------------------------------------------------------------------------
-- Date        Programmer  Vers  Description
-- =========== =========== ===== ==============================================
-- 07-JUN-2017 Infosys     1.0  Initial version
-- 14-AUG-2026 Copilot     2.0  Refactored: eliminated duplication, fixed bugs
--                              improved error handling, added retry logic
-------------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE BODY xxoks_star_count_loylty_pkg
AS
  -- Constants
  c_procedure_name       CONSTANT VARCHAR2(100) := 'XXOKS_STAR_COUNT_LOYLTY_PKG.MAIN_PROC';
  c_module               CONSTANT VARCHAR2(10)  := 'OKS';
  c_data_dir             CONSTANT VARCHAR2(200) := '$PODATA_IMP';
  c_ctl_dir              CONSTANT VARCHAR2(200) := '$XXSBUX_TOP/bin/ctl';
  c_max_retries          CONSTANT PLS_INTEGER   := 60;  -- Max 120 seconds (60 * 2s)
  c_retry_sleep_seconds  CONSTANT PLS_INTEGER   := 2;

  -- File load configuration type
  TYPE t_file_config IS RECORD (
    file_pattern   VARCHAR2(200),
    ctl_file       VARCHAR2(40),
    target_table   VARCHAR2(30)
  );

  TYPE t_file_config_table IS TABLE OF t_file_config INDEX BY PLS_INTEGER;

  -------------------------------------------------------------------------------
  -- PROCEDURE: submit_and_wait_for_sqlload
  -- PURPOSE: Submit SQL*Loader request and wait for completion
  -- PARAMETERS:
  --   p_file_pattern    - Wildcard pattern for data file
  --   p_ctl_file        - Control file name
  --   p_target_table    - Target table for update
  --   p_batch_id        - Batch ID for record identification
  --   x_request_id      - Returned request ID
  --   x_err_msg         - Error message if any
  -- RETURNS: TRUE if successful, FALSE otherwise
  -------------------------------------------------------------------------------
  FUNCTION submit_and_wait_for_sqlload (
    p_file_pattern  IN  VARCHAR2,
    p_ctl_file      IN  VARCHAR2,
    p_target_table  IN  VARCHAR2,
    p_batch_id      IN  NUMBER,
    x_request_id    OUT NUMBER,
    x_err_msg       OUT VARCHAR2
  ) RETURN BOOLEAN
  IS
    ln_request_id         NUMBER := 0;
    ln_retry_count        PLS_INTEGER := 0;
    ln_pending_count      NUMBER := 0;
    lv_status_message     VARCHAR2(500);
  BEGIN
    x_err_msg := NULL;
    x_request_id := 0;

    -- Submit the SQL*Loader request
    BEGIN
      lv_status_message := 'Submitting SQL*Loader for file: ' || p_file_pattern || 
                          ' to table: ' || p_target_table;
      xxglb_message_pkg.log_msg(lv_status_message);

      ln_request_id := fnd_request.submit_request (
        application   => 'XXSBUX',
        program       => 'XXGLB_SQLLOAD_FILE',
        description   => 'GLB Sqlload File SBUX',
        start_time    => NULL,
        sub_request   => FALSE,
        argument1     => c_module,
        argument2     => c_data_dir,
        argument3     => p_file_pattern,
        argument4     => c_ctl_dir,
        argument5     => p_ctl_file,
        argument6     => NULL,
        argument7     => NULL,
        argument8     => NULL,
        argument9     => NULL,
        argument10    => NULL,
        argument11    => 'N'
      );

      COMMIT;

      IF ln_request_id = 0
      THEN
        x_err_msg := 'Failed to submit SQL*Loader program. ' || SQLERRM;
        xxglb_message_pkg.log_msg('ERROR: ' || x_err_msg);
        RETURN FALSE;
      END IF;

      x_request_id := ln_request_id;

      -- Wait for request completion (with timeout)
      LOOP
        SELECT COUNT(*)
          INTO ln_pending_count
          FROM fnd_concurrent_requests
         WHERE request_id = ln_request_id
           AND phase_code <> 'C';

        IF ln_pending_count = 0
        THEN
          -- Request completed
          lv_status_message := 'SQL*Loader request ' || ln_request_id || 
                              ' completed for table: ' || p_target_table;
          xxglb_message_pkg.log_msg(lv_status_message);
          EXIT;
        END IF;

        ln_retry_count := ln_retry_count + 1;

        IF ln_retry_count > c_max_retries
        THEN
          x_err_msg := 'SQL*Loader request ' || ln_request_id || 
                      ' did not complete within timeout period (' || 
                      (c_max_retries * c_retry_sleep_seconds) || ' seconds).';
          xxglb_message_pkg.log_msg('WARNING: ' || x_err_msg);
          RETURN FALSE;
        END IF;

        DBMS_LOCK.SLEEP(c_retry_sleep_seconds);
      END LOOP;

      -- Update target table with request ID and batch ID
      UPDATE_TABLE_WITH_REQUEST(p_target_table, ln_request_id, p_batch_id, x_err_msg);

      RETURN TRUE;

    EXCEPTION
      WHEN OTHERS
      THEN
        x_err_msg := 'Unexpected error in submit_and_wait_for_sqlload for file ' || 
                    p_file_pattern || ': ' || SQLERRM;
        xxglb_message_pkg.log_msg('ERROR: ' || x_err_msg);
        RETURN FALSE;
    END;
  END submit_and_wait_for_sqlload;

  -------------------------------------------------------------------------------
  -- PROCEDURE: UPDATE_TABLE_WITH_REQUEST
  -- PURPOSE: Update target table with load request ID and batch ID
  -- PARAMETERS:
  --   p_target_table  - Name of table to update
  --   p_request_id    - Request ID from SQL*Loader
  --   p_batch_id      - Batch ID for record grouping
  --   x_err_msg       - Error message if any
  -------------------------------------------------------------------------------
  PROCEDURE UPDATE_TABLE_WITH_REQUEST (
    p_target_table IN VARCHAR2,
    p_request_id   IN NUMBER,
    p_batch_id     IN NUMBER,
    x_err_msg      OUT VARCHAR2
  )
  IS
    ln_rows_updated   PLS_INTEGER;
  BEGIN
    x_err_msg := NULL;

    EXECUTE IMMEDIATE 'UPDATE ' || p_target_table || 
                      ' SET load_request_id = :1, rec_id = :2' ||
                      ' WHERE load_request_id = -1 AND intf_status = ''new'''
      USING p_request_id, p_batch_id;

    ln_rows_updated := SQL%ROWCOUNT;

    IF ln_rows_updated > 0
    THEN
      xxglb_message_pkg.log_msg('Updated ' || ln_rows_updated || 
                               ' records in ' || p_target_table);
      COMMIT;
    ELSE
      xxglb_message_pkg.log_msg('No records to update in ' || p_target_table || 
                               ' with load_request_id = -1 and intf_status = new');
    END IF;

  EXCEPTION
    WHEN OTHERS
    THEN
      x_err_msg := 'Error updating ' || p_target_table || ': ' || SQLERRM;
      xxglb_message_pkg.log_msg('ERROR: ' || x_err_msg);
  END UPDATE_TABLE_WITH_REQUEST;

  -------------------------------------------------------------------------------
  -- MAIN PROCEDURE
  -- PURPOSE: Orchestrate loading of all star count loyalty files
  -- PARAMETERS:
  --   xv_err_buff - Output error message
  --   xn_ret_code - Output return code (0 = success, 1 = failure)
  -------------------------------------------------------------------------------
  PROCEDURE main_proc (
    xv_err_buff       OUT VARCHAR2,
    xn_ret_code       OUT NUMBER
  )
  IS
    ln_batch_id          NUMBER;
    lv_err_msg           VARCHAR2(2000);
    ln_request_id        NUMBER;
    ln_file_index        PLS_INTEGER;
    lb_all_success       BOOLEAN := TRUE;
    ln_success_count     PLS_INTEGER := 0;
    ln_failure_count     PLS_INTEGER := 0;

    -- Configuration for files to be loaded
    lt_file_configs      t_file_config_table;
  BEGIN
    xv_err_buff := NULL;
    xn_ret_code := 0;

    -- Initialize file configuration
    lt_file_configs(1).file_pattern := 'DailyAcountingExtract_*_1b_TierQualifying.csv';
    lt_file_configs(1).ctl_file     := 'xxoks_acct_ext_tl_grnted_sub.ctl';
    lt_file_configs(1).target_table := 'xxoks_acct_ext_tl_grnted_sub';

    lt_file_configs(2).file_pattern := 'DailyAcountingExtract_*_1_Earned.csv';
    lt_file_configs(2).ctl_file     := 'xxoks_acct_ext_gold_grnted_sub.ctl';
    lt_file_configs(2).target_table := 'xxoks_acct_ext_gold_grnted_sub';

    lt_file_configs(3).file_pattern := 'DailyAcountingExtract_*_2_Used.csv';
    lt_file_configs(3).ctl_file     := 'xxoks_acct_ext_used_sub.ctl';
    lt_file_configs(3).target_table := 'xxoks_acct_ext_used_sub';

    lt_file_configs(4).file_pattern := 'DailyAcountingExtract_*_3_RedemptionSource.csv';
    lt_file_configs(4).ctl_file     := 'xxoks_acct_ext_redmp_src_sub.ctl';
    lt_file_configs(4).target_table := 'xxoks_acct_ext_redmp_src_sub';

    lt_file_configs(5).file_pattern := 'DailyAcountingExtract_*_4_Outstanding.csv';
    lt_file_configs(5).ctl_file     := 'xxoks_acct_ext_outstanding.ctl';
    lt_file_configs(5).target_table := 'xxoks_acct_ext_outstanding';

    BEGIN
      -- Generate unique batch ID
      SELECT xxoks_acct_ext_batch_id_seq.NEXTVAL
        INTO ln_batch_id
        FROM DUAL;

      xxglb_message_pkg.log_msg('===========================================');
      xxglb_message_pkg.log_msg('Star Count Loyalty Load Process Started');
      xxglb_message_pkg.log_msg('Batch ID: ' || ln_batch_id);
      xxglb_message_pkg.log_msg('===========================================');

      -- Process each file configuration
      FOR ln_file_index IN lt_file_configs.FIRST .. lt_file_configs.LAST
      LOOP
        IF submit_and_wait_for_sqlload (
          p_file_pattern  => lt_file_configs(ln_file_index).file_pattern,
          p_ctl_file      => lt_file_configs(ln_file_index).ctl_file,
          p_target_table  => lt_file_configs(ln_file_index).target_table,
          p_batch_id      => ln_batch_id,
          x_request_id    => ln_request_id,
          x_err_msg       => lv_err_msg
        )
        THEN
          ln_success_count := ln_success_count + 1;
        ELSE
          ln_failure_count := ln_failure_count + 1;
          lb_all_success := FALSE;
          IF xv_err_buff IS NULL
          THEN
            xv_err_buff := lv_err_msg;
          ELSE
            xv_err_buff := xv_err_buff || '; ' || lv_err_msg;
          END IF;
        END IF;
      END LOOP;

      -- Summary logging
      xxglb_message_pkg.log_msg('===========================================');
      xxglb_message_pkg.log_msg('Process Summary:');
      xxglb_message_pkg.log_msg('  Successful Loads: ' || ln_success_count);
      xxglb_message_pkg.log_msg('  Failed Loads: ' || ln_failure_count);
      xxglb_message_pkg.log_msg('===========================================');

      -- Set return code
      IF lb_all_success
      THEN
        xn_ret_code := 0;
        xxglb_message_pkg.log_msg('All files loaded successfully.');
      ELSE
        xn_ret_code := 1;
        xxglb_message_pkg.log_msg('One or more files failed to load.');
      END IF;

    EXCEPTION
      WHEN OTHERS
      THEN
        xn_ret_code := 1;
        xv_err_buff := 'Unexpected error in main_proc: ' || SQLERRM;
        xxglb_message_pkg.log_msg('ERROR: ' || xv_err_buff);
    END;
  END main_proc;

END xxoks_star_count_loylty_pkg;
/

SHOW ERRORS
