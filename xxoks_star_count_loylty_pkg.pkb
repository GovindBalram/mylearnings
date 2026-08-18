/* Perforce $File: <path/file.ext> $ */
/* Perforce $Revision: <rev> $ $DateTime: <yyyy/mm/dd hh:mi:ss> $ */
-------------------------------------------------------------------------------
-- Script Name        :  xxoks_star_count_loylty_pkg.pkb
-- Object Name        :  XXOKS_STAR_COUNT_LOYLTY_PKG
-- Description        :  Package for loading the star count allocation data
-------------------------------------------------------------------------------
-- Date        Programmer  Vers  Description
-- =========== =========== ===== ==============================================
-- 07-JUN-2017 Infosys     1.0  Initial version
-------------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE BODY xxoks_star_count_loylty_pkg
AS    
  PROCEDURE main_proc (xv_err_buff       OUT VARCHAR2,
                       xn_ret_code       OUT NUMBER)
  IS
    cv_procedure              CONSTANT VARCHAR2 (100):= 'XXOKS_STAR_COUNT_LOYLTY_PKG.MAIN_PROC' ;
    lv_module                 CONSTANT VARCHAR2 (10) := 'OKS';
    --
    lv_operation_name         VARCHAR2 (2000);
    lv_operation_key          VARCHAR2 (2000);
    ln_load_request_id        NUMBER := NULL;
    lv_request_status         VARCHAR2 (20);
    ln_count                  NUMBER := NULL;
    ln_batch_id               NUMBER;
    --
    l_data_dir                VARCHAR2(200) := '$PODATA_IMP'; --'$OKSDATA_IMP';
    l_ctl_dir                 VARCHAR2(200) := '$XXSBUX_TOP/bin/ctl';
    lv_remote_file_1b         VARCHAR2(200);
    lv_cntr_file_1b           VARCHAR2(40);
    lv_remote_file_1          VARCHAR2(200);
    lv_cntr_file_1            VARCHAR2(40);
    lv_remote_file_2          VARCHAR2(200);
    lv_cntr_file_2            VARCHAR2(40);	  
    lv_remote_file_3          VARCHAR2(200);
    lv_cntr_file_3            VARCHAR2(40);
    lv_remote_file_4          VARCHAR2(200);
    lv_cntr_file_4            VARCHAR2(40);
  BEGIN
    BEGIN
      SELECT xxoks_acct_ext_batch_id_seq.NEXTVAL
        INTO ln_batch_id
        FROM DUAL;
      --
      xxglb_message_pkg.log_msg('Batch ID - '||ln_batch_id);
      --
      lv_operation_name := 'Call to GLB Load Files SBUX';
      lv_remote_file_1b := 'DailyAcountingExtract_'||'*_1b_TierQualifying.csv';
      lv_cntr_file_1b   := 'xxoks_acct_ext_tl_grnted_sub.ctl';
      lv_operation_key  := 'Load File:' || lv_remote_file_1b;
      lv_request_status := NULL;
      xxglb_message_pkg.log_msg(lv_operation_name||'loading'||lv_remote_file_1b);	 
      --------------------------------------
      -- Submit Global Sql Loader Request --
      --------------------------------------
      ln_load_request_id := fnd_request.submit_request ( application   => 'XXSBUX',
                                                        program       => 'XXGLB_SQLLOAD_FILE',
                                                        description   => 'GLB Sqlload File SBUX',
                                                        start_time    => NULL,
                                                        sub_request   => FALSE,
                                                        argument1     => lv_module,
                                                        argument2     => l_data_dir,
                                                        argument3     => lv_remote_file_1b,
                                                        argument4     => l_ctl_dir,
                                                        argument5     => lv_cntr_file_1b,
                                                        argument6     => NULL,
                                                        argument7     => NULL,
                                                        argument8     => NULL,
                                                        argument9     => NULL,
                                                        argument10    => NULL,
                                                        argument11    => 'N');
      --
      COMMIT;
      --
      IF ln_load_request_id = 0
      THEN
          xxglb_message_pkg.log_msg('Failed in submitting XXGLB_SQLLOAD_FILE program : '||SQLERRM);
      ELSE
        BEGIN
          <<check_status>>
          ln_count := NULL;
          --  
          SELECT COUNT (*)
            INTO ln_count
            FROM fnd_concurrent_requests
           WHERE request_id = ln_load_request_id
             AND phase_code <> 'C';
          --
          IF ln_count > 0
          THEN
            DBMS_LOCK.SLEEP(2);
            GOTO check_status;
          END IF;
        END;
      END IF;
      --
      UPDATE xxoks_acct_ext_tl_grnted_sub
         SET load_request_id = ln_load_request_id,
             rec_id = ln_batch_id
       WHERE load_request_id = -1
         AND intf_status= 'new';
    EXCEPTION
      WHEN OTHERS
      THEN
        xxglb_message_pkg.log_msg ('Unexpected error occurred while submitting XXGLB_SQLLOAD_FILE program:'
                                 || SQLERRM);
    END;
    --
    BEGIN
      lv_operation_name := 'Call to GLB Load Files SBUX';
	  lv_remote_file_1  := 'DailyAcountingExtract_'||'*_1_Earned.csv';
      lv_cntr_file_1    := 'xxoks_acct_ext_gold_grnted_sub.ctl';
      lv_operation_key  := 'Load File:' || lv_remote_file_1;
	  lv_request_status := NULL;
      xxglb_message_pkg.log_msg(lv_operation_name||'loading'||lv_remote_file_1);	 
	  --------------------------------------
       -- Submit Global Sql Loader Request --
      --------------------------------------
      ln_load_request_id := fnd_request.submit_request ( application   => 'XXSBUX',
                                                        program       => 'XXGLB_SQLLOAD_FILE',
                                                        description   => 'GLB Sqlload File SBUX',
                                                        start_time    => NULL,
                                                        sub_request   => FALSE,
                                                        argument1     => lv_module,
                                                        argument2     => l_data_dir,
                                                        argument3     => lv_remote_file_1,
                                                        argument4     => l_ctl_dir,
                                                        argument5     => lv_cntr_file_1,
                                                        argument6     => NULL,
                                                        argument7     => NULL,
                                                        argument8     => NULL,
                                                        argument9     => NULL,
                                                        argument10    => NULL,
                                                        argument11    => 'N');
      --
      COMMIT;
      --
	  IF ln_load_request_id = 0
      THEN
        xxglb_message_pkg.log_msg('Failed in submitting XXGLB_SQLLOAD_FILE program : '||SQLERRM);
      ELSE
        BEGIN
          <<check_status>>
          ln_count := NULL;
          --  
          SELECT COUNT (*)
            INTO ln_count
            FROM fnd_concurrent_requests
           WHERE request_id = ln_load_request_id
             AND phase_code <> 'C';
          --
          IF ln_count > 0
          THEN
            DBMS_LOCK.SLEEP(2);
            GOTO check_status;
          END IF;
        END;
      END IF;
      --
      UPDATE xxoks_acct_ext_gold_grnted_sub
         SET load_request_id = ln_load_request_id,
             rec_id = ln_batch_id
       WHERE load_request_id = -1
         AND intf_status= 'new';
    EXCEPTION
      WHEN OTHERS
      THEN
        xxglb_message_pkg.log_msg ('Unexpected error occurred while submitting XXGLB_SQLLOAD_FILE program:'
                                 || SQLERRM);
    END;
    --
    BEGIN
      lv_operation_name := 'Call to GLB Load Files SBUX';
	  lv_remote_file_2  := 'DailyAcountingExtract_'||'*_2_Used.csv';
      lv_cntr_file_2    := 'xxoks_acct_ext_used_sub.ctl';
      lv_operation_key  := 'Load File:' || lv_remote_file_2;
	  lv_request_status :=  NULL;
      xxglb_message_pkg.log_msg(lv_operation_name||'loading'||lv_remote_file_2);	 
	  --------------------------------------
       -- Submit Global Sql Loader Request --
      --------------------------------------
      ln_load_request_id := fnd_request.submit_request ( application   => 'XXSBUX',
                                                        program       => 'XXGLB_SQLLOAD_FILE',
                                                        description   => 'GLB Sqlload File SBUX',
                                                        start_time    => NULL,
                                                        sub_request   => FALSE,
                                                        argument1     => lv_module,
                                                        argument2     => l_data_dir,
                                                        argument3     => lv_remote_file_2,
                                                        argument4     => l_ctl_dir,
                                                        argument5     => lv_cntr_file_2,
                                                        argument6     => NULL,
                                                        argument7     => NULL,
                                                        argument8     => NULL,
                                                        argument9     => NULL,
                                                        argument10    => NULL,
                                                        argument11    => 'N');
      --
      COMMIT;
      --
	  IF ln_load_request_id = 0
      THEN
          xxglb_message_pkg.log_msg('Failed in submitting XXGLB_SQLLOAD_FILE program : '||SQLERRM);
      ELSE
        BEGIN
          <<check_status>>
          ln_count := NULL;
          --  
          SELECT COUNT (*)
            INTO ln_count
            FROM fnd_concurrent_requests
           WHERE request_id = ln_load_request_id
             AND phase_code <> 'C';
          --
          IF ln_count > 0
          THEN
            DBMS_LOCK.SLEEP(2);
            GOTO check_status;
          END IF;
        END;
      END IF;
      --
      UPDATE xxoks_acct_ext_used_sub
         SET load_request_id = ln_load_request_id,
             rec_id = ln_batch_id
       WHERE load_request_id = -1
         AND intf_status= 'new';
    EXCEPTION
      WHEN OTHERS
      THEN
        xxglb_message_pkg.log_msg ('Unexpected error occurred while submitting XXGLB_SQLLOAD_FILE program:'
                                 || SQLERRM);
    END;
	--
	BEGIN
      lv_operation_name := 'Call to GLB Load Files SBUX';
	  lv_remote_file_3  := 'DailyAcountingExtract_'||'*_3_RedemptionSource.csv';
      lv_cntr_file_3    := 'xxoks_acct_ext_redmp_src_sub.ctl';
      lv_operation_key  := 'Load File:' || lv_remote_file_3;
	  lv_request_status := NULL;
      xxglb_message_pkg.log_msg(lv_operation_name||'loading'||lv_remote_file_3);	 
	  --------------------------------------
       -- Submit Global Sql Loader Request --
      --------------------------------------
      ln_load_request_id := fnd_request.submit_request ( application   => 'XXSBUX',
                                                        program       => 'XXGLB_SQLLOAD_FILE',
                                                        description   => 'GLB Sqlload File SBUX',
                                                        start_time    => NULL,
                                                        sub_request   => FALSE,
                                                        argument1     => lv_module,
                                                        argument2     => l_data_dir,
                                                        argument3     => lv_remote_file_3,
                                                        argument4     => l_ctl_dir,
                                                        argument5     => lv_cntr_file_3,
                                                        argument6     => NULL,
                                                        argument7     => NULL,
                                                        argument8     => NULL,
                                                        argument9     => NULL,
                                                        argument10    => NULL,
                                                        argument11    => 'N');
      --
      COMMIT;
      -- 
	  IF ln_load_request_id = 0
      THEN
          xxglb_message_pkg.log_msg('Failed in submitting XXGLB_SQLLOAD_FILE program : '||SQLERRM);
      ELSE
        BEGIN
          <<check_status>>
          ln_count := NULL;
          --  
          SELECT COUNT (*)
            INTO ln_count
            FROM fnd_concurrent_requests
           WHERE request_id = ln_load_request_id
             AND phase_code <> 'C';
          --
          IF ln_count > 0
          THEN
            DBMS_LOCK.SLEEP(2);
            GOTO check_status;
          END IF;
        END;
      END IF;
      --
      UPDATE xxoks_acct_ext_redmp_src_sub
         SET load_request_id = ln_load_request_id,
             rec_id = ln_batch_id
       WHERE load_request_id = -1
         AND intf_status= 'new';
    EXCEPTION
      WHEN OTHERS
      THEN
        xxglb_message_pkg.log_msg ('Unexpected error occurred while submitting XXGLB_SQLLOAD_FILE program:'
                                 || SQLERRM);
    END;
    --
	BEGIN
      lv_operation_name := 'Call to GLB Load Files SBUX';
	  lv_remote_file_4  := 'DailyAcountingExtract_'||'*_4_Outstanding.csv';
      lv_cntr_file_4    := 'xxoks_acct_ext_outstanding.ctl';
      lv_operation_key  := 'Load File:' || lv_remote_file_3;
	  lv_request_status := NULL;
      xxglb_message_pkg.log_msg(lv_operation_name||'loading'||lv_remote_file_4);	 
	  --------------------------------------
       -- Submit Global Sql Loader Request --
      --------------------------------------
      ln_load_request_id := fnd_request.submit_request ( application   => 'XXSBUX',
                                                        program       => 'XXGLB_SQLLOAD_FILE',
                                                        description   => 'GLB Sqlload File SBUX',
                                                        start_time    => NULL,
                                                        sub_request   => FALSE,
                                                        argument1     => lv_module,
                                                        argument2     => l_data_dir,
                                                        argument3     => lv_remote_file_4,
                                                        argument4     => l_ctl_dir,
                                                        argument5     => lv_cntr_file_4,
                                                        argument6     => NULL,
                                                        argument7     => NULL,
                                                        argument8     => NULL,
                                                        argument9     => NULL,
                                                        argument10    => NULL,
                                                        argument11    => 'N');
      --
      COMMIT;
      --
      IF ln_load_request_id = 0
      THEN
          xxglb_message_pkg.log_msg('Failed in submitting XXGLB_SQLLOAD_FILE program : '||SQLERRM);
      ELSE
        BEGIN
          <<check_status>>
          ln_count := NULL;
          --  
          SELECT COUNT (*)
            INTO ln_count
            FROM fnd_concurrent_requests
           WHERE request_id = ln_load_request_id
             AND phase_code <> 'C';
          --
          IF ln_count > 0
          THEN
            DBMS_LOCK.SLEEP(2);
            GOTO check_status;
          END IF;
        END;
      END IF;
      --
      UPDATE xxoks_acct_ext_outstanding
         SET load_request_id = ln_load_request_id
       WHERE load_request_id = -1;
    EXCEPTION
      WHEN OTHERS
      THEN
        xxglb_message_pkg.log_msg ('Unexpected error occurred while submitting XXGLB_SQLLOAD_FILE program:'
                                 || SQLERRM);
    END;
  EXCEPTION
    WHEN OTHERS
    THEN
      xxglb_message_pkg.log_msg ('Unexpected error occurred in procedure main_proc:'|| SQLERRM); 
  END main_proc;
END xxoks_star_count_loylty_pkg;
/

SHOW ERRORS