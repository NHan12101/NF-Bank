'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { apiFetch } from '../api';
import Navbar from '../components/Navbar';

export default function DashboardPage() {
  const router = useRouter();
  const [accounts, setAccounts] = useState([]);
  const [transactions, setTransactions] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    async function fetchData() {
      try {
        // Fetch accounts
        const accRes = await apiFetch('/accounts');
        const accData = await accRes.json();

        if (accRes.ok && accData.success) {
          setAccounts(accData.data || []);
          
          // Fetch transactions
          const txRes = await apiFetch('/transactions');
          const txData = await txRes.json();
          if (txRes.ok && txData.success) {
            setTransactions(txData.data || []);
          }
        } else {
          setError(accData.message || 'Không thể tải thông tin tài khoản.');
        }
      } catch (err) {
        setError('Đã xảy ra lỗi kết nối. Vui lòng thử lại sau.');
      } finally {
        setLoading(false);
      }
    }
    fetchData();
  }, []);

  const formatCurrency = (amount, currency) => {
    if (currency === 'VND') {
      return new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' }).format(amount);
    }
    return new Intl.NumberFormat('en-US', { style: 'currency', currency: currency || 'USD' }).format(amount);
  };

  // Find payment account ID to determine transfer direction
  const paymentAccount = accounts.find(acc => acc.account_type === 'PAYMENT');
  const paymentAccountId = paymentAccount ? paymentAccount.id : null;

  return (
    <>
      <Navbar />
      <main className="dashboard-grid" id="dashboard-main">
        {loading ? (
          <div style={{ gridColumn: '1 / -1', textAlign: 'center', padding: '40px' }} id="dashboard-loading">
            <div className="spinner pulse-animation" />
            <p style={{ color: 'var(--text-secondary)' }}>Đang tải dữ liệu tài khoản...</p>
          </div>
        ) : error ? (
          <div style={{ gridColumn: '1 / -1' }} id="dashboard-error">
            <div className="alert alert-danger" role="alert">
              {error}
            </div>
          </div>
        ) : (
          <>
            {/* Left Column: Account Details & Action Buttons */}
            <div className="dashboard-card" id="accounts-card" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
              <h2 id="accounts-title">Tài khoản thanh toán</h2>
              {accounts.length === 0 ? (
                <p style={{ color: 'var(--text-secondary)' }} id="no-accounts-msg">Bạn chưa có tài khoản nào hoạt động.</p>
              ) : (
                accounts.map(acc => (
                  <div key={acc.id} className="account-item" id={`account-item-${acc.account_number}`}>
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                      <span style={{ fontWeight: '600', fontSize: '1.1rem' }}>
                        {acc.account_type === 'PAYMENT' ? 'Tài khoản nguồn chính' : 'Tài khoản tiết kiệm'}
                      </span>
                      <span className="account-num">
                        Số tài khoản: <strong>{acc.account_number}</strong>
                      </span>
                      <span style={{ fontSize: '0.8rem', color: acc.status === 'ACTIVE' ? 'var(--success)' : 'var(--error)' }}>
                        Trạng thái: {acc.status}
                      </span>
                    </div>
                    <div>
                      <span className="account-balance">
                        {formatCurrency(acc.balance, acc.currency)}
                      </span>
                    </div>
                  </div>
                ))
              )}

              <div style={{ marginTop: '10px', display: 'flex', gap: '12px' }} id="dashboard-actions">
                <button
                  id="dashboard-transfer-shortcut-btn"
                  onClick={() => router.push('/transfer')}
                  className="btn btn-primary"
                  style={{ flex: 1 }}
                >
                  Chuyển tiền nhanh
                </button>
              </div>
            </div>

            {/* Right Column: Recent Transactions */}
            <div className="dashboard-card" id="transactions-card">
              <h2 id="transactions-title">Giao dịch gần đây</h2>
              {transactions.length === 0 ? (
                <p style={{ color: 'var(--text-secondary)', marginTop: '20px', textAlign: 'center' }} id="no-transactions-msg">
                  Chưa có giao dịch nào được thực hiện.
                </p>
              ) : (
                <div className="transaction-list" id="transaction-list">
                  {transactions.map(tx => {
                    const isSender = tx.sender_account_id === paymentAccountId;
                    return (
                      <div key={tx.id} className="transaction-item" id={`transaction-item-${tx.reference_code}`}>
                        <div className="transaction-details">
                          <span className="tx-desc">{tx.description || 'Chuyển tiền'}</span>
                          <span className="tx-time">Mã GD: {tx.reference_code}</span>
                        </div>
                        <div style={{ textAlign: 'right' }}>
                          <span className={`tx-amount ${isSender ? 'withdrawal' : 'deposit'}`}>
                            {isSender ? '-' : '+'} {formatCurrency(tx.amount, tx.currency)}
                          </span>
                          <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginTop: '2px' }}>
                            {tx.status}
                          </div>
                        </div>
                      </div>
                    );
                  })}
                </div>
              )}
            </div>
          </>
        )}
      </main>
    </>
  );
}
