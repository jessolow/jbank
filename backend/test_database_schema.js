// Database Schema Verification Test
// Tests that all required database objects exist and are properly configured

const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = 'https://navolchoccoxcjkkwkcb.supabase.co';
const SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5hdm9sY2hvY2NveGNqa2t3a2NiIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NTI1MzczOCwiZXhwIjoyMDcwODI5NzM4fQ.UfrgrBTUTptvoX0zjwF3NrV-wbfRG0bw2TaNdNJxEwA';

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

const testResults = {
    passed: 0,
    failed: 0,
    tests: []
};

function logTest(name, passed, details = '') {
    const status = passed ? '✅ PASS' : '❌ FAIL';
    const result = { name, passed, details, timestamp: new Date().toISOString() };
    testResults.tests.push(result);
    
    if (passed) {
        testResults.passed++;
        console.log(`${status}: ${name}`);
    } else {
        testResults.failed++;
        console.log(`${status}: ${name} - ${details}`);
    }
    
    return result;
}

// Test 1: Check if all required schemas exist
async function testSchemas() {
    console.log('\n🏗️  Testing Database Schemas...');
    
    const requiredSchemas = [
        'public',
        'deposit_core',
        'lending_core',
        'history'
    ];
    
    for (const schema of requiredSchemas) {
        try {
            const { data, error } = await supabase
                .from('information_schema.schemata')
                .select('schema_name')
                .eq('schema_name', schema)
                .single();
            
            const exists = !error && data && data.schema_name === schema;
            logTest(`Schema: ${schema}`, exists, 
                exists ? 'Schema exists' : `Error: ${error?.message || 'Not found'}`);
        } catch (error) {
            logTest(`Schema: ${schema}`, false, `Error: ${error.message}`);
        }
    }
}

// Test 2: Check if all required tables exist
async function testTables() {
    console.log('\n📋 Testing Database Tables...');
    
    const requiredTables = [
        { schema: 'public', table: 'customer_profile' },
        { schema: 'deposit_core', table: 'deposit_accounts' },
        { schema: 'lending_core', table: 'loc_accounts' },
        { schema: 'lending_core', table: 'term_loans' },
        { schema: 'lending_core', table: 'repayment_schedule' },
        { schema: 'lending_core', table: 'loan_loc_mapping' },
        { schema: 'history', table: 'events' }
    ];
    
    for (const { schema, table } of requiredTables) {
        try {
            const { data, error } = await supabase
                .from('information_schema.tables')
                .select('table_name')
                .eq('table_schema', schema)
                .eq('table_name', table)
                .single();
            
            const exists = !error && data && data.table_name === table;
            logTest(`Table: ${schema}.${table}`, exists, 
                exists ? 'Table exists' : `Error: ${error?.message || 'Not found'}`);
        } catch (error) {
            logTest(`Table: ${schema}.${table}`, false, `Error: ${error.message}`);
        }
    }
}

// Test 3: Check if all required views exist
async function testViews() {
    console.log('\n👁️  Testing Database Views...');
    
    const requiredViews = [
        { schema: 'public', view: 'account_balances' },
        { schema: 'lending_core', view: 'loc_exposure' },
        { schema: 'lending_core', view: 'loan_ledger_accounts' },
        { schema: 'history', view: 'timeline_by_customer' }
    ];
    
    for (const { schema, view } of requiredViews) {
        try {
            const { data, error } = await supabase
                .from('information_schema.views')
                .select('table_name')
                .eq('table_schema', schema)
                .eq('table_name', view)
                .single();
            
            const exists = !error && data && data.table_name === view;
            logTest(`View: ${schema}.${view}`, exists, 
                exists ? 'View exists' : `Error: ${error?.message || 'Not found'}`);
        } catch (error) {
            logTest(`View: ${schema}.${view}`, false, `Error: ${error.message}`);
        }
    }
}

// Test 4: Check if all required functions exist
async function testFunctions() {
    console.log('\n⚙️  Testing Database Functions...');
    
    const requiredFunctions = [
        { schema: 'public', function: 'get_or_create_profile' },
        { schema: 'public', function: 'post_balanced_transaction' },
        { schema: 'public', function: 'has_service_role' },
        { schema: 'history', function: 'add_event' }
    ];
    
    for (const { schema, function: funcName } of requiredFunctions) {
        try {
            const { data, error } = await supabase
                .from('information_schema.routines')
                .select('routine_name')
                .eq('routine_schema', schema)
                .eq('routine_name', funcName)
                .single();
            
            const exists = !error && data && data.routine_name === funcName;
            logTest(`Function: ${schema}.${funcName}()`, exists, 
                exists ? 'Function exists' : `Error: ${error?.message || 'Not found'}`);
        } catch (error) {
            logTest(`Function: ${schema}.${funcName}()`, false, `Error: ${error.message}`);
        }
    }
}

// Test 5: Check if RLS is enabled on tables
async function testRLS() {
    console.log('\n🔒 Testing Row Level Security...');
    
    const tablesWithRLS = [
        { schema: 'public', table: 'customer_profile' },
        { schema: 'deposit_core', table: 'deposit_accounts' },
        { schema: 'lending_core', table: 'loc_accounts' },
        { schema: 'lending_core', table: 'term_loans' },
        { schema: 'lending_core', table: 'repayment_schedule' }
    ];
    
    for (const { schema, table } of tablesWithRLS) {
        try {
            const { data, error } = await supabase
                .from('pg_tables')
                .select('rowsecurity')
                .eq('schemaname', schema)
                .eq('tablename', table)
                .single();
            
            const hasRLS = !error && data && data.rowsecurity === true;
            logTest(`RLS on ${schema}.${table}`, hasRLS, 
                hasRLS ? 'RLS enabled' : `RLS disabled or not found`);
        } catch (error) {
            logTest(`RLS on ${schema}.${table}`, false, `Error: ${error.message}`);
        }
    }
}

// Test 6: Check if triggers exist
async function testTriggers() {
    console.log('\n🎯 Testing Database Triggers...');
    
    const requiredTriggers = [
        { schema: 'deposit_core', trigger: 'create_ledger_account' },
        { schema: 'lending_core', trigger: 'create_loan_ledger_accounts' }
    ];
    
    for (const { schema, trigger } of requiredTriggers) {
        try {
            const { data, error } = await supabase
                .from('information_schema.triggers')
                .select('trigger_name')
                .eq('trigger_schema', schema)
                .eq('trigger_name', trigger)
                .single();
            
            const exists = !error && data && data.trigger_name === trigger;
            logTest(`Trigger: ${schema}.${trigger}`, exists, 
                exists ? 'Trigger exists' : `Error: ${error?.message || 'Not found'}`);
        } catch (error) {
            logTest(`Trigger: ${schema}.${trigger}`, false, `Error: ${error.message}`);
        }
    }
}

// Test 7: Check if indexes exist
async function testIndexes() {
    console.log('\n📊 Testing Database Indexes...');
    
    const requiredIndexes = [
        { schema: 'public', table: 'customer_profile', index: 'idx_customer_profile_user_id' },
        { schema: 'history', table: 'events', index: 'idx_events_occurred_at' },
        { schema: 'history', table: 'events', index: 'idx_events_event_type' }
    ];
    
    for (const { schema, table, index } of requiredIndexes) {
        try {
            const { data, error } = await supabase
                .from('pg_indexes')
                .select('indexname')
                .eq('schemaname', schema)
                .eq('tablename', table)
                .eq('indexname', index)
                .single();
            
            const exists = !error && data && data.indexname === index;
            logTest(`Index: ${schema}.${table}.${index}`, exists, 
                exists ? 'Index exists' : `Error: ${error?.message || 'Not found'}`);
        } catch (error) {
            logTest(`Index: ${schema}.${table}.${index}`, false, `Error: ${error.message}`);
        }
    }
}

// Test 8: Check basic data access
async function testDataAccess() {
    console.log('\n🔍 Testing Basic Data Access...');
    
    try {
        // Test if we can query the customer_profile table
        const { data, error } = await supabase
            .from('customer_profile')
            .select('*')
            .limit(1);
        
        const canAccess = !error;
        logTest('Data Access: customer_profile', canAccess, 
            canAccess ? 'Can query table' : `Error: ${error?.message}`);
        
    } catch (error) {
        logTest('Data Access: customer_profile', false, `Error: ${error.message}`);
    }
}

// Main test runner
async function runAllTests() {
    console.log('🏗️  Starting Database Schema Verification Tests...\n');
    console.log('=' .repeat(60));
    
    try {
        await testSchemas();
        await testTables();
        await testViews();
        await testFunctions();
        await testRLS();
        await testTriggers();
        await testIndexes();
        await testDataAccess();
        
    } catch (error) {
        console.error('❌ Test suite failed with error:', error);
    }
    
    // Print summary
    console.log('\n' + '=' .repeat(60));
    console.log('📊 DATABASE SCHEMA TEST SUMMARY');
    console.log('=' .repeat(60));
    console.log(`✅ Passed: ${testResults.passed}`);
    console.log(`❌ Failed: ${testResults.failed}`);
    console.log(`📈 Success Rate: ${((testResults.passed / (testResults.passed + testResults.failed)) * 100).toFixed(1)}%`);
    
    if (testResults.failed === 0) {
        console.log('\n🎉 All database schema tests passed! The database is properly configured.');
    } else {
        console.log('\n⚠️  Some database schema tests failed. Check the details above.');
    }
    
    // Save detailed results
    const fs = require('fs');
    fs.writeFileSync('database_test_results.json', JSON.stringify(testResults, null, 2));
    console.log('\n📄 Detailed results saved to database_test_results.json');
}

// Run tests
runAllTests().catch(console.error);
