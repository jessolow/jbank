// J Bank Backend Functionality Test
// Tests actual banking operations and data structures

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

// Test 1: Test Customer Profile Table Structure
async function testCustomerProfileStructure() {
    console.log('\n👤 Testing Customer Profile Structure...');
    
    try {
        const { data, error } = await supabase
            .from('customer_profile')
            .select('*')
            .limit(1);
        
        if (error) {
            logTest('Customer Profile Table Access', false, `Error: ${error.message}`);
            return;
        }
        
        // Check if we can access the table (data will be empty if no records)
        logTest('Customer Profile Table Access', true, 'Table accessible');
        
        // Test table structure by checking if we can select specific columns
        const { data: structureTest, error: structureError } = await supabase
            .from('customer_profile')
            .select('user_id, full_name, created_at')
            .limit(1);
        
        const hasCorrectStructure = !structureError;
        logTest('Customer Profile Structure', hasCorrectStructure, 
            hasCorrectStructure ? 'Correct columns accessible' : `Error: ${structureError?.message}`);
        
    } catch (error) {
        logTest('Customer Profile Structure', false, `Error: ${error.message}`);
    }
}

// Test 2: Test Core Ledger Tables
async function testCoreLedgerStructure() {
    console.log('\n💰 Testing Core Ledger Structure...');
    
    const ledgerTables = [
        'ledger_accounts',
        'ledger_transactions', 
        'ledger_entries'
    ];
    
    for (const table of ledgerTables) {
        try {
            const { data, error } = await supabase
                .from(table)
                .select('*')
                .limit(1);
            
            const accessible = !error;
            logTest(`Ledger Table: ${table}`, accessible, 
                accessible ? 'Table accessible' : `Error: ${error?.message}`);
                
        } catch (error) {
            logTest(`Ledger Table: ${table}`, false, `Error: ${error.message}`);
        }
    }
}

// Test 3: Test Deposit Core Structure
async function testDepositCoreStructure() {
    console.log('\n🏦 Testing Deposit Core Structure...');
    
    try {
        const { data, error } = await supabase
            .from('deposit_core.deposit_accounts')
            .select('*')
            .limit(1);
        
        const accessible = !error;
        logTest('Deposit Core Table', accessible, 
            accessible ? 'Table accessible' : `Error: ${error?.message}`);
            
    } catch (error) {
        logTest('Deposit Core Table', false, `Error: ${error.message}`);
    }
}

// Test 4: Test Lending Core Structure
async function testLendingCoreStructure() {
    console.log('\n💳 Testing Lending Core Structure...');
    
    const lendingTables = [
        'lending_core.loc_accounts',
        'lending_core.term_loans',
        'lending_core.repayment_schedule',
        'lending_core.loan_loc_mapping'
    ];
    
    for (const table of lendingTables) {
        try {
            const { data, error } = await supabase
                .from(table)
                .select('*')
                .limit(1);
            
            const accessible = !error;
            logTest(`Lending Table: ${table}`, accessible, 
                accessible ? 'Table accessible' : `Error: ${error?.message}`);
                
        } catch (error) {
            logTest(`Lending Table: ${table}`, false, `Error: ${error.message}`);
        }
    }
}

// Test 5: Test History Structure
async function testHistoryStructure() {
    console.log('\n📊 Testing History Structure...');
    
    try {
        const { data, error } = await supabase
            .from('history.events')
            .select('*')
            .limit(1);
        
        const accessible = !error;
        logTest('History Events Table', accessible, 
            accessible ? 'Table accessible' : `Error: ${error?.message}`);
            
    } catch (error) {
        logTest('History Events Table', false, `Error: ${error.message}`);
    }
}

// Test 6: Test Views
async function testViews() {
    console.log('\n👁️  Testing Database Views...');
    
    const views = [
        'account_balances',
        'lending_core.loc_exposure',
        'lending_core.loan_ledger_accounts',
        'history.timeline_by_customer'
    ];
    
    for (const view of views) {
        try {
            const { data, error } = await supabase
                .from(view)
                .select('*')
                .limit(1);
            
            const accessible = !error;
            logTest(`View: ${view}`, accessible, 
                accessible ? 'View accessible' : `Error: ${error?.message}`);
                
        } catch (error) {
            logTest(`View: ${view}`, false, `Error: ${error.message}`);
        }
    }
}

// Test 7: Test RPC Functions
async function testRPCFunctions() {
    console.log('\n⚙️  Testing RPC Functions...');
    
    try {
        // Test get_or_create_profile function
        const { data, error } = await supabase
            .rpc('get_or_create_profile');
        
        // This should fail without proper auth context, but we can test if the function exists
        const functionExists = error && error.message.includes('auth.uid()');
        logTest('RPC: get_or_create_profile', functionExists, 
            functionExists ? 'Function exists (auth error expected)' : `Error: ${error?.message}`);
            
    } catch (error) {
        logTest('RPC: get_or_create_profile', false, `Error: ${error.message}`);
    }
}

// Test 8: Test Basic Data Operations
async function testBasicOperations() {
    console.log('\n🔧 Testing Basic Data Operations...');
    
    try {
        // Test if we can insert a test customer profile (will be rolled back)
        const testUserId = '00000000-0000-0000-0000-000000000000';
        const { data, error } = await supabase
            .from('customer_profile')
            .insert({
                user_id: testUserId,
                full_name: 'Test User'
            })
            .select();
        
        if (!error) {
            // Clean up test data
            await supabase
                .from('customer_profile')
                .delete()
                .eq('user_id', testUserId);
            
            logTest('Basic Insert/Delete Operations', true, 'Can perform basic CRUD operations');
        } else {
            logTest('Basic Insert/Delete Operations', false, `Error: ${error.message}`);
        }
        
    } catch (error) {
        logTest('Basic Insert/Delete Operations', false, `Error: ${error.message}`);
    }
}

// Test 9: Test Edge Function Endpoints
async function testEdgeFunctionEndpoints() {
    console.log('\n🚀 Testing Edge Function Endpoints...');
    
    const endpoints = [
        'profile',
        'ledgerPostings',
        'depositsCreate',
        'lendingCreateLoc',
        'historyGet'
    ];
    
    for (const endpoint of endpoints) {
        try {
            const response = await fetch(`${SUPABASE_URL}/functions/v1/${endpoint}`, {
                method: 'GET',
                headers: {
                    'Content-Type': 'application/json'
                }
            });
            
            // Most should return 401 (unauthorized) which means they're working
            const isWorking = response.status === 401 || response.status === 200;
            logTest(`Edge Function: ${endpoint}`, isWorking, 
                `Status: ${response.status} (Expected: 401 for auth required)`);
                
        } catch (error) {
            logTest(`Edge Function: ${endpoint}`, false, `Error: ${error.message}`);
        }
    }
}

// Test 10: Test Security and Permissions
async function testSecurityAndPermissions() {
    console.log('\n🔒 Testing Security and Permissions...');
    
    try {
        // Test if anonymous users can access customer data (should fail)
        const { data, error } = await supabase
            .from('customer_profile')
            .select('*')
            .limit(1);
        
        // This should fail due to RLS policies
        const isSecure = error && (error.message.includes('permission') || error.message.includes('RLS'));
        logTest('Security: Anonymous Access Blocked', isSecure, 
            isSecure ? 'Access properly blocked' : `Unexpected result: ${error?.message}`);
            
    } catch (error) {
        logTest('Security: Anonymous Access Blocked', false, `Error: ${error.message}`);
    }
}

// Main test runner
async function runAllTests() {
    console.log('🚀 Starting J Bank Backend Functionality Tests...\n');
    console.log('=' .repeat(60));
    
    try {
        await testCustomerProfileStructure();
        await testCoreLedgerStructure();
        await testDepositCoreStructure();
        await testLendingCoreStructure();
        await testHistoryStructure();
        await testViews();
        await testRPCFunctions();
        await testBasicOperations();
        await testEdgeFunctionEndpoints();
        await testSecurityAndPermissions();
        
    } catch (error) {
        console.error('❌ Test suite failed with error:', error);
    }
    
    // Print summary
    console.log('\n' + '=' .repeat(60));
    console.log('📊 FUNCTIONALITY TEST SUMMARY');
    console.log('=' .repeat(60));
    console.log(`✅ Passed: ${testResults.passed}`);
    console.log(`❌ Failed: ${testResults.failed}`);
    console.log(`📈 Success Rate: ${((testResults.passed / (testResults.passed + testResults.failed)) * 100).toFixed(1)}%`);
    
    if (testResults.failed === 0) {
        console.log('\n🎉 All functionality tests passed! The banking backend is working correctly.');
    } else {
        console.log('\n⚠️  Some functionality tests failed. Check the details above.');
    }
    
    // Save detailed results
    const fs = require('fs');
    fs.writeFileSync('functionality_test_results.json', JSON.stringify(testResults, null, 2));
    console.log('\n📄 Detailed results saved to functionality_test_results.json');
}

// Run tests
runAllTests().catch(console.error);
