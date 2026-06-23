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

  // States for creating account
  const [showCreateAccountModal, setShowCreateAccountModal] = useState(false);
  const [newAccountType, setNewAccountType] = useState('PAYMENT');
  const [newAccountCurrency, setNewAccountCurrency] = useState('VND');
  const [createAccountLoading, setCreateAccountLoading] = useState(false);
  const [createAccountError, setCreateAccountError] = useState('');
  const [createAccountSuccess, setCreateAccountSuccess] = useState('');

  // States for transaction details
  const [showTransactionModal, setShowTransactionModal] = useState(false);
  const [selectedTransaction, setSelectedTransaction] = useState(null);
  const [transactionDetailLoading, setTransactionDetailLoading] = useState(false);
  const [transactionDetailError, setTransactionDetailError] = useState('');

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

  const getAccountTypeName = (type) => {
    switch (type) {
      case 'PAYMENT': return 'Tài khoản nguồn chính';
      case 'SAVINGS': return 'Tài khoản tiết kiệm';
      case 'CREDIT': return 'Tài khoản tín dụng';
      default: return 'Tài khoản khác';
    }
  };

  const handleCreateAccountSubmit = async (e) => {
    e.preventDefault();
    setCreateAccountError('');
    setCreateAccountSuccess('');
    setCreateAccountLoading(true);

    try {
      const res = await apiFetch('/accounts', {
        method: 'POST',
        body: JSON.stringify({
          account_type: newAccountType,
          currency: newAccountCurrency
        })
      });
      const data = await res.json();
      if (res.ok && data.success) {
        setCreateAccountSuccess('Mở tài khoản thành công!');
        
        // Refresh accounts list
        const accRes = await apiFetch('/accounts');
        const accData = await accRes.json();
        if (accRes.ok && accData.success) {
          setAccounts(accData.data || []);
        }

        setTimeout(() => {
          setShowCreateAccountModal(false);
        }, 1500);
      } else {
        setCreateAccountError(data.message || 'Mở tài khoản thất bại.');
      }
    } catch (err) {
      setCreateAccountError('Lỗi kết nối đến máy chủ.');
    } finally {
      setCreateAccountLoading(false);
    }
  };

  const handleViewTransactionDetails = async (referenceCode) => {
    setTransactionDetailLoading(true);
    setTransactionDetailError('');
    setSelectedTransaction(null);
    setShowTransactionModal(true);
    try {
      const res = await apiFetch(`/transactions/${referenceCode}`);
      const data = await res.json();
      if (res.ok && data.success) {
        setSelectedTransaction(data.data);
      } else {
        setTransactionDetailError(data.message || 'Không thể tải chi tiết giao dịch.');
      }
    } catch (err) {
      setTransactionDetailError('Lỗi kết nối khi tải chi tiết giao dịch.');
    } finally {
      setTransactionDetailLoading(false);
    }
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
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <h2 id="accounts-title" style={{ margin: 0 }}>Tài khoản của bạn</h2>
                <button
                  id="dashboard-open-account-modal-btn"
                  onClick={() => {
                    setCreateAccountError('');
                    setCreateAccountSuccess('');
                    setShowCreateAccountModal(true);
                  }}
                  className="btn btn-primary"
                  style={{ width: 'auto', padding: '8px 16px', fontSize: '0.85rem', borderRadius: '8px' }}
                >
                  + Mở tài khoản
                </button>
              </div>
              
              {accounts.length === 0 ? (
                <p style={{ color: 'var(--text-secondary)' }} id="no-accounts-msg">Bạn chưa có tài khoản nào hoạt động.</p>
              ) : (
                accounts.map(acc => (
                  <div key={acc.id} className="account-item" id={`account-item-${acc.account_number}`}>
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                      <span style={{ fontWeight: '600', fontSize: '1.1rem' }}>
                        {getAccountTypeName(acc.account_type)}
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
                      <div
                        key={tx.id}
                        className="transaction-item"
                        id={`transaction-item-${tx.reference_code}`}
                        onClick={() => handleViewTransactionDetails(tx.reference_code)}
                        style={{ cursor: 'pointer', transition: 'background 0.2s', border: '1px solid transparent' }}
                        onMouseEnter={(e) => e.currentTarget.style.background = 'rgba(255, 255, 255, 0.05)'}
                        onMouseLeave={(e) => e.currentTarget.style.background = 'rgba(255, 255, 255, 0.02)'}
                        title="Bấm để xem chi tiết giao dịch"
                      >
                        <div className="transaction-details">
                          <span className="tx-desc" style={{ maxWidth: '200px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                            {tx.description || 'Chuyển tiền'}
                          </span>
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

      {/* Modal: Open New Account */}
      {showCreateAccountModal && (
        <div style={{
          position: 'fixed',
          top: 0, left: 0, right: 0, bottom: 0,
          background: 'rgba(5, 6, 11, 0.85)',
          backdropFilter: 'blur(8px)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          zIndex: 1000,
          padding: '20px'
        }} id="create-account-modal-overlay">
          <div className="glass-container" style={{ maxWidth: '420px', border: '1px solid var(--primary)' }}>
            <h2 style={{ fontSize: '1.5rem', marginBottom: '12px' }}>Mở tài khoản mới</h2>
            <p className="subtitle" style={{ fontSize: '0.9rem', marginBottom: '20px' }}>
              Tạo thêm ví tài khoản thanh toán (PAYMENT) để giao dịch bằng VND hoặc USD.
            </p>

            {createAccountError && (
              <div className="alert alert-danger" role="alert" style={{ padding: '12px', fontSize: '0.9rem', marginBottom: '16px' }}>
                {createAccountError}
              </div>
            )}

            {createAccountSuccess && (
              <div className="alert alert-success" role="alert" style={{ padding: '12px', fontSize: '0.9rem', marginBottom: '16px' }}>
                {createAccountSuccess}
              </div>
            )}

            <form onSubmit={handleCreateAccountSubmit}>
              <div className="form-group" style={{ marginBottom: '16px' }}>
                <label>Loại tài khoản</label>
                <div style={{
                  padding: '14px 16px',
                  background: 'rgba(0, 0, 0, 0.2)',
                  border: '1px solid var(--glass-border)',
                  borderRadius: '12px',
                  fontSize: '0.95rem',
                  color: 'var(--text-secondary)'
                }}>
                  Tài khoản thanh toán (PAYMENT)
                </div>
                <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginTop: '4px' }}>
                  *Lưu ý: Tài khoản Tiết kiệm (SAVINGS) và Tín dụng (CREDIT) chỉ có thể được mở bởi Quản trị viên.
                </span>
              </div>

              <div className="form-group" style={{ marginBottom: '24px' }}>
                <label>Loại tiền tệ</label>
                <select
                  value={newAccountCurrency}
                  onChange={(e) => setNewAccountCurrency(e.target.value)}
                  disabled={createAccountLoading}
                  style={{ background: 'rgba(0,0,0,0.3)', border: '1px solid var(--glass-border)', color: '#fff' }}
                >
                  <option value="VND" style={{ background: '#0d0f1a' }}>VND (Việt Nam Đồng)</option>
                  <option value="USD" style={{ background: '#0d0f1a' }}>USD (Đô la Mỹ)</option>
                </select>
              </div>

              <div style={{ display: 'flex', gap: '12px' }}>
                <button
                  type="button"
                  className="btn btn-secondary"
                  onClick={() => setShowCreateAccountModal(false)}
                  disabled={createAccountLoading}
                >
                  Hủy bỏ
                </button>
                <button
                  type="submit"
                  className="btn btn-primary"
                  disabled={createAccountLoading}
                >
                  {createAccountLoading ? 'Đang xử lý...' : 'Xác nhận mở'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Modal: Transaction Details */}
      {showTransactionModal && (
        <div style={{
          position: 'fixed',
          top: 0, left: 0, right: 0, bottom: 0,
          background: 'rgba(5, 6, 11, 0.85)',
          backdropFilter: 'blur(8px)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          zIndex: 1000,
          padding: '20px'
        }} id="transaction-detail-modal-overlay">
          <div className="glass-container" style={{ maxWidth: '500px', border: '1px solid var(--secondary)' }}>
            <h2 style={{ fontSize: '1.5rem', marginBottom: '12px' }}>Chi tiết giao dịch</h2>
            <p className="subtitle" style={{ fontSize: '0.9rem', marginBottom: '20px' }}>
              Thông tin chi tiết về mã giao dịch đã thực hiện.
            </p>

            {transactionDetailLoading ? (
              <div style={{ textAlign: 'center', padding: '30px' }}>
                <div className="spinner pulse-animation" />
                <p style={{ color: 'var(--text-secondary)' }}>Đang tải chi tiết...</p>
              </div>
            ) : transactionDetailError ? (
              <div className="alert alert-danger" role="alert">
                {transactionDetailError}
              </div>
            ) : selectedTransaction ? (
              <div style={{ display: 'flex', flexDirection: 'column', gap: '14px', textAlign: 'left', background: 'rgba(0,0,0,0.2)', padding: '16px', borderRadius: '12px', border: '1px solid var(--glass-border)', fontSize: '0.95rem' }}>
                <div>
                  <span style={{ color: 'var(--text-secondary)', display: 'block', fontSize: '0.8rem', textTransform: 'uppercase', fontWeight: 'bold' }}>Mã tham chiếu (Reference)</span>
                  <strong style={{ color: '#fff', fontSize: '1.1rem' }}>{selectedTransaction.reference_code}</strong>
                </div>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px' }}>
                  <div>
                    <span style={{ color: 'var(--text-secondary)', display: 'block', fontSize: '0.8rem', textTransform: 'uppercase', fontWeight: 'bold' }}>Loại giao dịch</span>
                    <span style={{ fontWeight: '600', color: 'var(--secondary)' }}>{selectedTransaction.type}</span>
                  </div>
                  <div>
                    <span style={{ color: 'var(--text-secondary)', display: 'block', fontSize: '0.8rem', textTransform: 'uppercase', fontWeight: 'bold' }}>Trạng thái</span>
                    <span style={{ fontWeight: '600', color: selectedTransaction.status === 'SUCCESS' ? 'var(--success)' : 'var(--error)' }}>
                      {selectedTransaction.status}
                    </span>
                  </div>
                </div>
                <div>
                  <span style={{ color: 'var(--text-secondary)', display: 'block', fontSize: '0.8rem', textTransform: 'uppercase', fontWeight: 'bold' }}>Số tiền giao dịch</span>
                  <strong style={{ fontSize: '1.4rem', color: selectedTransaction.sender_account_id === paymentAccountId ? 'var(--error)' : 'var(--success)' }}>
                    {selectedTransaction.sender_account_id === paymentAccountId ? '-' : '+'} {formatCurrency(selectedTransaction.amount, selectedTransaction.currency)}
                  </strong>
                </div>
                {selectedTransaction.sender_account_id && (
                  <div>
                    <span style={{ color: 'var(--text-secondary)', display: 'block', fontSize: '0.8rem', textTransform: 'uppercase', fontWeight: 'bold' }}>Mã tài khoản gửi</span>
                    <span style={{ fontFamily: 'monospace' }}>ID: {selectedTransaction.sender_account_id}</span>
                  </div>
                )}
                <div>
                  <span style={{ color: 'var(--text-secondary)', display: 'block', fontSize: '0.8rem', textTransform: 'uppercase', fontWeight: 'bold' }}>Mã tài khoản nhận</span>
                  <span style={{ fontFamily: 'monospace' }}>ID: {selectedTransaction.receiver_account_id}</span>
                </div>
                <div>
                  <span style={{ color: 'var(--text-secondary)', display: 'block', fontSize: '0.8rem', textTransform: 'uppercase', fontWeight: 'bold' }}>Mô tả / Nội dung</span>
                  <p style={{ margin: '4px 0 0 0', color: '#fff', fontSize: '0.9rem', lineHeight: '1.4', background: 'rgba(0,0,0,0.15)', padding: '8px', borderRadius: '6px', border: '1px solid rgba(255,255,255,0.03)' }}>
                    {selectedTransaction.description || 'Không có nội dung'}
                  </p>
                </div>
              </div>
            ) : null}

            <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: '20px' }}>
              <button
                type="button"
                className="btn btn-secondary"
                style={{ width: 'auto', padding: '10px 20px', borderRadius: '10px' }}
                onClick={() => setShowTransactionModal(false)}
              >
                Đóng
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
}
