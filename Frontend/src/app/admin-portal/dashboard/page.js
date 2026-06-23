'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { apiFetch, getAccessToken, getUser } from '../../api';
import AdminNavbar from '../components/AdminNavbar';

export default function AdminDashboardPage() {
  const router = useRouter();
  const [currentUser, setCurrentUser] = useState(null);
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [activeTab, setActiveTab] = useState('customers'); // 'customers' or 'admins'

  // Accounts modal states
  const [selectedUser, setSelectedUser] = useState(null);
  const [showAccountsModal, setShowAccountsModal] = useState(false);
  const [userAccounts, setUserAccounts] = useState([]);
  const [modalLoading, setModalLoading] = useState(false);
  const [modalError, setModalError] = useState('');
  const [modalSuccess, setModalSuccess] = useState('');
  const [creationCurrency, setCreationCurrency] = useState('VND');

  // Deposit and history states
  const [showDepositForm, setShowDepositForm] = useState(null); // stores account_number
  const [depositAmount, setDepositAmount] = useState('');
  const [depositDescription, setDepositDescription] = useState('');
  const [depositLoading, setDepositLoading] = useState(false);
  
  const [showHistoryFor, setShowHistoryFor] = useState(null); // stores account_number
  const [accountTransactions, setAccountTransactions] = useState([]);
  const [historyLoading, setHistoryLoading] = useState(false);

  // Child admin creation states
  const [newAdminName, setNewAdminName] = useState('');
  const [newAdminEmail, setNewAdminEmail] = useState('');
  const [newAdminPhone, setNewAdminPhone] = useState('');
  const [newAdminPassword, setNewAdminPassword] = useState('');
  const [createAdminLoading, setCreateAdminLoading] = useState(false);
  const [createdAdminResult, setCreatedAdminResult] = useState(null); // Displays setup popup
  const [copiedSecret, setCopiedSecret] = useState(false);

  const fetchUsers = async () => {
    setLoading(true);
    try {
      const res = await apiFetch('/admin/users');
      const data = await res.json();

      if (res.ok && data.success) {
        setUsers(data.data || []);
      } else {
        setError(data.message || 'Không thể tải danh sách tài khoản.');
      }
    } catch (err) {
      setError('Đã xảy ra lỗi kết nối. Vui lòng thử lại sau.');
    } finally {
      setLoading(false);
    }
  };

  const fetchUserAccounts = async (userId) => {
    setModalLoading(true);
    setModalError('');
    setModalSuccess('');
    try {
      const res = await apiFetch(`/admin/users/${userId}/accounts`);
      const data = await res.json();
      if (res.ok && data.success) {
        setUserAccounts(data.data || []);
      } else {
        setModalError(data.message || 'Không thể tải danh sách ví tài khoản.');
      }
    } catch (err) {
      setModalError('Đã xảy ra lỗi kết nối.');
    } finally {
      setModalLoading(false);
    }
  };

  const handleCreateAccount = async (userId, accountType) => {
    setModalLoading(true);
    setModalError('');
    setModalSuccess('');
    try {
      const res = await apiFetch(`/admin/users/${userId}/accounts`, {
        method: 'POST',
        body: JSON.stringify({
          account_type: accountType,
          currency: creationCurrency
        })
      });
      const data = await res.json();
      if (res.ok && data.success) {
        setModalSuccess(`Đã cấp tài khoản ${accountType} thành công.`);
        fetchUserAccounts(userId); // Refresh accounts list
      } else {
        setModalError(data.message || 'Cấp tài khoản thất bại.');
      }
    } catch (err) {
      setModalError('Đã xảy ra lỗi kết nối.');
    } finally {
      setModalLoading(false);
    }
  };

  const handleDeposit = async (accountNumber) => {
    const amountVal = parseInt(depositAmount);
    if (!depositAmount || isNaN(amountVal) || amountVal <= 0) {
      setModalError('Số tiền nạp phải là số dương lớn hơn 0.');
      return;
    }
    setDepositLoading(true);
    setModalError('');
    setModalSuccess('');
    try {
      const res = await apiFetch('/admin/deposit', {
        method: 'POST',
        body: JSON.stringify({
          receiver_account_number: accountNumber,
          amount: amountVal,
          description: depositDescription.trim()
        })
      });
      const data = await res.json();
      if (res.ok && data.success) {
        setModalSuccess(`Đã nạp thành công ${new Intl.NumberFormat('vi-VN').format(amountVal)} VND vào tài khoản ${accountNumber}.`);
        setDepositAmount('');
        setDepositDescription('');
        setShowDepositForm(null);
        fetchUserAccounts(selectedUser.id); // Refresh accounts list
      } else {
        setModalError(data.message || 'Nạp tiền thất bại.');
      }
    } catch (err) {
      setModalError('Lỗi kết nối khi nạp tiền.');
    } finally {
      setDepositLoading(false);
    }
  };

  const handleToggleHistory = async (accountId, accountNumber) => {
    if (showHistoryFor === accountNumber) {
      setShowHistoryFor(null);
      setAccountTransactions([]);
      return;
    }

    setHistoryLoading(true);
    setShowHistoryFor(accountNumber);
    setAccountTransactions([]);
    setModalError('');
    setModalSuccess('');

    try {
      const res = await apiFetch(`/admin/accounts/${accountId}/transactions`);
      const data = await res.json();
      if (res.ok && data.success) {
        setAccountTransactions(data.data || []);
      } else {
        setModalError(data.message || 'Không thể tải lịch sử giao dịch.');
        setShowHistoryFor(null);
      }
    } catch (err) {
      setModalError('Lỗi kết nối khi tải lịch sử.');
      setShowHistoryFor(null);
    } finally {
      setHistoryLoading(false);
    }
  };

  const handleLockUser = async (userId, userName) => {
    if (!window.confirm(`Bạn có chắc chắn muốn KHÓA tài khoản của ${userName}?`)) {
      return;
    }
    setError('');
    setSuccess('');
    try {
      const res = await apiFetch(`/admin/users/${userId}/lock`, {
        method: 'PATCH'
      });
      const data = await res.json();

      if (res.ok && data.success) {
        setSuccess(`Đã khóa tài khoản ${userName} thành công.`);
        fetchUsers();
      } else {
        setError(data.message || 'Không thể khóa tài khoản.');
      }
    } catch (err) {
      setError('Đã xảy ra lỗi kết nối.');
    }
  };

  const handleUnlockUser = async (userId, userName) => {
    if (!window.confirm(`Bạn có chắc chắn muốn MỞ KHÓA tài khoản của ${userName}?`)) {
      return;
    }
    setError('');
    setSuccess('');
    try {
      const res = await apiFetch(`/admin/users/${userId}/unlock`, {
        method: 'PATCH'
      });
      const data = await res.json();

      if (res.ok && data.success) {
        setSuccess(`Đã mở khóa tài khoản ${userName} thành công.`);
        fetchUsers();
      } else {
        setError(data.message || 'Không thể mở khóa tài khoản.');
      }
    } catch (err) {
      setError('Đã xảy ra lỗi kết nối.');
    }
  };

  const handleCreateAdmin = async (e) => {
    e.preventDefault();
    setError('');
    setSuccess('');
    setCreateAdminLoading(true);

    try {
      const res = await apiFetch('/admin/create-admin', {
        method: 'POST',
        body: JSON.stringify({
          full_name: newAdminName.trim(),
          email: newAdminEmail.trim(),
          phone: newAdminPhone.trim(),
          password: newAdminPassword
        })
      });

      const data = await res.json();

      if (res.ok && data.success) {
        setCreatedAdminResult(data.data);
        setSuccess('Đã tạo tài khoản Admin con thành công!');
        // Clear fields
        setNewAdminName('');
        setNewAdminEmail('');
        setNewAdminPhone('');
        setNewAdminPassword('');
        fetchUsers(); // Refresh list to include new admin
      } else {
        setError(data.message || 'Tạo tài khoản Admin thất bại.');
      }
    } catch (err) {
      setError('Lỗi kết nối khi tạo Admin.');
    } finally {
      setCreateAdminLoading(false);
    }
  };

  const copyToClipboard = (text) => {
    navigator.clipboard.writeText(text);
    setCopiedSecret(true);
    setTimeout(() => setCopiedSecret(false), 2000);
  };

  useEffect(() => {
    const token = getAccessToken();
    const u = getUser();

    if (!token || !u) {
      router.push('/admin-portal/login');
      return;
    }

    if (u.role !== 'admin' && u.role !== 'super_admin') {
      router.push('/dashboard');
      return;
    }

    setCurrentUser(u);
    fetchUsers();
  }, [router]);

  if (!currentUser) {
    return (
      <div style={{ display: 'flex', flex: 1, alignItems: 'center', justifyContent: 'center', minHeight: '100vh' }}>
        <div className="spinner pulse-animation" />
      </div>
    );
  }

  const customerUsers = users.filter(u => u.role === 'user');
  const adminUsers = users.filter(u => u.role === 'admin');

  return (
    <>
      <AdminNavbar />
      <main style={{ padding: '40px 20px', maxWidth: '1200px', margin: '0 auto', width: '100%', flex: 1 }} id="admin-main">
        
        {/* Header Section */}
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '32px' }}>
          <div>
            <h1 id="admin-title">Hệ thống Quản trị</h1>
            <p className="subtitle" style={{ margin: 0 }} id="admin-subtitle">
              Quản lý tài khoản khách hàng, khóa/mở khóa và cấp ví dịch vụ.
            </p>
          </div>
          <button 
            onClick={fetchUsers} 
            className="btn btn-secondary" 
            style={{ width: 'auto', padding: '10px 20px', fontSize: '0.9rem', borderRadius: '10px' }}
            disabled={loading}
          >
            {loading ? 'Đang tải...' : 'Làm mới dữ liệu'}
          </button>
        </div>

        {error && (
          <div className="alert alert-danger" role="alert" id="admin-error-alert" style={{ marginBottom: '24px' }}>
            {error}
          </div>
        )}

        {success && (
          <div className="alert alert-success" role="alert" id="admin-success-alert" style={{ marginBottom: '24px' }}>
            {success}
          </div>
        )}

        {/* Custom Tab Navigation */}
        <div style={{
          display: 'flex',
          borderBottom: '1px solid var(--glass-border)',
          marginBottom: '24px',
          gap: '8px'
        }}>
          <button
            onClick={() => setActiveTab('customers')}
            style={{
              padding: '12px 24px',
              background: 'none',
              border: 'none',
              borderBottom: activeTab === 'customers' ? '2px solid var(--primary)' : 'none',
              color: activeTab === 'customers' ? 'var(--text-primary)' : 'var(--text-secondary)',
              fontSize: '1rem',
              fontWeight: '600',
              cursor: 'pointer',
              transition: 'all 0.3s'
            }}
          >
            👥 Khách hàng ({customerUsers.length})
          </button>

          {currentUser.role === 'super_admin' && (
            <button
              onClick={() => setActiveTab('admins')}
              style={{
                padding: '12px 24px',
                background: 'none',
                border: 'none',
                borderBottom: activeTab === 'admins' ? '2px solid var(--accent)' : 'none',
                color: activeTab === 'admins' ? 'var(--text-primary)' : 'var(--text-secondary)',
                fontSize: '1rem',
                fontWeight: '600',
                cursor: 'pointer',
                transition: 'all 0.3s'
              }}
            >
              🛡️ Quản lý Admin con ({adminUsers.length})
            </button>
          )}
        </div>

        {/* Tab 1: Customers */}
        {activeTab === 'customers' && (
          loading ? (
            <div style={{ textAlign: 'center', padding: '60px' }} id="admin-table-loading">
              <div className="spinner pulse-animation" />
              <p style={{ color: 'var(--text-secondary)', marginTop: '12px' }}>Đang tải danh sách khách hàng...</p>
            </div>
          ) : (
            <div className="dashboard-card" style={{ padding: '0', overflowX: 'auto', border: '1px solid var(--glass-border)' }}>
              <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left', fontSize: '0.95rem' }}>
                <thead>
                  <tr style={{ borderBottom: '2px solid var(--glass-border)', background: 'rgba(255, 255, 255, 0.02)' }}>
                    <th style={{ padding: '16px 20px', color: 'var(--text-secondary)', fontWeight: '600' }}>ID</th>
                    <th style={{ padding: '16px 20px', color: 'var(--text-secondary)', fontWeight: '600' }}>Họ và tên</th>
                    <th style={{ padding: '16px 20px', color: 'var(--text-secondary)', fontWeight: '600' }}>Email</th>
                    <th style={{ padding: '16px 20px', color: 'var(--text-secondary)', fontWeight: '600' }}>Số điện thoại</th>
                    <th style={{ padding: '16px 20px', color: 'var(--text-secondary)', fontWeight: '600' }}>Trạng thái tài khoản</th>
                    <th style={{ padding: '16px 20px', color: 'var(--text-secondary)', fontWeight: '600', textAlign: 'center' }}>Hành động</th>
                  </tr>
                </thead>
                <tbody>
                  {customerUsers.length === 0 ? (
                    <tr>
                      <td colSpan="6" style={{ padding: '40px', textAlign: 'center', color: 'var(--text-muted)' }}>
                        Không tìm thấy khách hàng nào trong hệ thống.
                      </td>
                    </tr>
                  ) : (
                    customerUsers.map((u) => (
                      <tr 
                        key={u.id} 
                        style={{ borderBottom: '1px solid var(--glass-border)', transition: 'background 0.3s' }}
                        onMouseEnter={(e) => e.currentTarget.style.background = 'rgba(255,255,255,0.02)'}
                        onMouseLeave={(e) => e.currentTarget.style.background = 'none'}
                      >
                        <td style={{ padding: '16px 20px', color: 'var(--text-muted)' }}>{u.id}</td>
                        <td style={{ padding: '16px 20px', fontWeight: '500' }}>{u.full_name}</td>
                        <td style={{ padding: '16px 20px' }}>{u.email}</td>
                        <td style={{ padding: '16px 20px' }}>{u.phone}</td>
                        <td style={{ padding: '16px 20px' }}>
                          <div style={{ display: 'flex', flexDirection: 'column', gap: '2px' }}>
                            <span>
                              {u.is_locked ? (
                                <span style={{ color: 'var(--error)', fontWeight: '600' }}>🔒 Đã khóa</span>
                              ) : (
                                <span style={{ color: 'var(--success)', fontWeight: '600' }}>🔓 Hoạt động</span>
                              )}
                            </span>
                            <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
                              Xác minh: {u.is_verified ? 'Đã kích hoạt' : 'Chưa'}
                            </span>
                          </div>
                        </td>
                        <td style={{ padding: '16px 20px', textAlign: 'center', display: 'flex', gap: '8px', justifyContent: 'center' }}>
                          <button
                            onClick={() => {
                              setSelectedUser(u);
                              setShowAccountsModal(true);
                              fetchUserAccounts(u.id);
                            }}
                            className="btn"
                            style={{
                              width: 'auto',
                              padding: '6px 14px',
                              fontSize: '0.8rem',
                              borderRadius: '8px',
                              background: 'rgba(99, 102, 241, 0.15)',
                              color: 'var(--primary)',
                              border: '1px solid rgba(99, 102, 241, 0.3)',
                              fontWeight: '600'
                            }}
                          >
                            Quản lý ví
                          </button>

                          {u.is_locked ? (
                            <button
                              onClick={() => handleUnlockUser(u.id, u.full_name)}
                              className="btn"
                              style={{
                                width: 'auto',
                                padding: '6px 14px',
                                fontSize: '0.8rem',
                                borderRadius: '8px',
                                background: 'rgba(16, 185, 129, 0.15)',
                                color: 'var(--success)',
                                border: '1px solid rgba(16, 185, 129, 0.3)',
                                fontWeight: '600'
                              }}
                            >
                              Mở khóa
                            </button>
                          ) : (
                            <button
                              onClick={() => handleLockUser(u.id, u.full_name)}
                              className="btn"
                              style={{
                                width: 'auto',
                                padding: '6px 14px',
                                fontSize: '0.8rem',
                                borderRadius: '8px',
                                background: 'rgba(239, 68, 68, 0.15)',
                                color: 'var(--error)',
                                border: '1px solid rgba(239, 68, 68, 0.3)',
                                fontWeight: '600'
                              }}
                            >
                              Khóa
                            </button>
                          )}
                        </td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          )
        )}

        {/* Tab 2: Admin accounts management (Only Super Admin) */}
        {activeTab === 'admins' && currentUser.role === 'super_admin' && (
          <div style={{
            display: 'grid',
            gridTemplateColumns: '2fr 1fr',
            gap: '30px',
            alignItems: 'start'
          }} id="super-admin-layout">
            
            {/* Admin accounts list */}
            <div className="dashboard-card" style={{ padding: '0', overflowX: 'auto', border: '1px solid var(--glass-border)' }}>
              <h2 style={{ fontSize: '1.25rem', padding: '20px 20px 10px', color: '#fff' }}>Danh sách Admin con</h2>
              <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left', fontSize: '0.95rem' }}>
                <thead>
                  <tr style={{ borderBottom: '2px solid var(--glass-border)', background: 'rgba(255, 255, 255, 0.02)' }}>
                    <th style={{ padding: '16px 20px', color: 'var(--text-secondary)', fontWeight: '600' }}>ID</th>
                    <th style={{ padding: '16px 20px', color: 'var(--text-secondary)', fontWeight: '600' }}>Họ và tên</th>
                    <th style={{ padding: '16px 20px', color: 'var(--text-secondary)', fontWeight: '600' }}>Tên đăng nhập</th>
                    <th style={{ padding: '16px 20px', color: 'var(--text-secondary)', fontWeight: '600' }}>Số điện thoại</th>
                    <th style={{ padding: '16px 20px', color: 'var(--text-secondary)', fontWeight: '600' }}>Trạng thái</th>
                  </tr>
                </thead>
                <tbody>
                  {adminUsers.length === 0 ? (
                    <tr>
                      <td colSpan="5" style={{ padding: '30px', textAlign: 'center', color: 'var(--text-muted)' }}>
                        Chưa có tài khoản Admin con nào được tạo.
                      </td>
                    </tr>
                  ) : (
                    adminUsers.map((u) => (
                      <tr 
                        key={u.id} 
                        style={{ borderBottom: '1px solid var(--glass-border)' }}
                      >
                        <td style={{ padding: '16px 20px', color: 'var(--text-muted)' }}>{u.id}</td>
                        <td style={{ padding: '16px 20px', fontWeight: '500' }}>{u.full_name}</td>
                        <td style={{ padding: '16px 20px' }}>{u.email}</td>
                        <td style={{ padding: '16px 20px' }}>{u.phone}</td>
                        <td style={{ padding: '16px 20px' }}>
                          <span style={{ color: 'var(--success)', fontWeight: '600' }}>🔓 Hoạt động</span>
                        </td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>

            {/* Create child admin form */}
            <div className="glass-container" style={{ padding: '24px', maxWidth: '100%' }}>
              <h2 style={{ fontSize: '1.25rem', marginBottom: '16px', color: '#fff' }}>Tạo Admin con mới</h2>
              <form onSubmit={handleCreateAdmin}>
                <div className="form-group">
                  <label>Họ và tên</label>
                  <input
                    type="text"
                    required
                    placeholder="Nguyễn Văn A"
                    value={newAdminName}
                    onChange={(e) => setNewAdminName(e.target.value)}
                    disabled={createAdminLoading}
                  />
                </div>

                <div className="form-group">
                  <label>Tên đăng nhập / Email</label>
                  <input
                    type="text"
                    required
                    placeholder="admin_username hoặc email"
                    value={newAdminEmail}
                    onChange={(e) => setNewAdminEmail(e.target.value)}
                    disabled={createAdminLoading}
                  />
                </div>

                <div className="form-group">
                  <label>Số điện thoại</label>
                  <input
                    type="text"
                    required
                    placeholder="0868xxxxxx"
                    value={newAdminPhone}
                    onChange={(e) => setNewAdminPhone(e.target.value)}
                    disabled={createAdminLoading}
                  />
                </div>

                <div className="form-group" style={{ marginBottom: '24px' }}>
                  <label>Mật khẩu</label>
                  <input
                    type="password"
                    required
                    placeholder="Tối thiểu 8 ký tự"
                    value={newAdminPassword}
                    onChange={(e) => setNewAdminPassword(e.target.value)}
                    disabled={createAdminLoading}
                  />
                </div>

                <button
                  type="submit"
                  className="btn btn-primary"
                  disabled={createAdminLoading}
                  style={{
                    padding: '12px',
                    borderRadius: '10px',
                    fontWeight: 'bold',
                    background: 'linear-gradient(135deg, var(--accent) 0%, #c026d3 100%)'
                  }}
                >
                  {createAdminLoading ? 'Đang tạo...' : 'Tạo tài khoản Admin'}
                </button>
              </form>
            </div>
          </div>
        )}

      </main>

      {/* Modal: Accounts Management */}
      {showAccountsModal && selectedUser && (
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
        }} id="accounts-modal-overlay">
          <div className="glass-container" style={{ maxWidth: '550px', border: '1px solid var(--primary)', maxHeight: '90vh', overflowY: 'auto' }} id="accounts-modal-container">
            <h2 style={{ fontSize: '1.5rem', marginBottom: '8px' }}>Quản lý ví tài khoản</h2>
            <p className="subtitle" style={{ fontSize: '0.85rem', marginBottom: '20px' }}>
              Người dùng: <strong>{selectedUser.full_name}</strong> | Email: {selectedUser.email}
            </p>

            {modalError && (
              <div className="alert alert-danger" role="alert" id="modal-error-alert" style={{ padding: '12px', fontSize: '0.9rem', marginBottom: '16px' }}>
                {modalError}
              </div>
            )}

            {modalSuccess && (
              <div className="alert alert-success" role="alert" id="modal-success-alert" style={{ padding: '12px', fontSize: '0.9rem', marginBottom: '16px' }}>
                {modalSuccess}
              </div>
            )}

            {modalLoading && userAccounts.length === 0 ? (
              <div style={{ textAlign: 'center', padding: '20px' }} id="modal-spinner">
                <div className="spinner pulse-animation" style={{ width: '30px', height: '30px' }} />
              </div>
            ) : (
              <div style={{ marginBottom: '24px' }}>
                <h3 style={{ fontSize: '1.1rem', color: 'var(--text-secondary)', marginBottom: '12px' }}>Các tài khoản hiện có:</h3>
                {userAccounts.length === 0 ? (
                  <p style={{ color: 'var(--text-muted)', fontSize: '0.9rem' }}>Khách hàng chưa có ví tài khoản nào hoạt động.</p>
                ) : (
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }} id="modal-accounts-list">
                    {userAccounts.map(acc => (
                      <div key={acc.id} style={{
                        background: 'rgba(0, 0, 0, 0.25)',
                        border: '1px solid var(--glass-border)',
                        borderRadius: '10px',
                        padding: '12px 16px',
                        display: 'flex',
                        flexDirection: 'column',
                        gap: '12px'
                      }} id={`modal-account-item-${acc.account_number}`}>
                        {/* Main Account Info */}
                        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                          <div>
                            <div style={{ fontWeight: '600', color: '#fff' }}>
                              {acc.account_type === 'PAYMENT' && '💳 TÀI KHOẢN NGUỒN (PAYMENT)'}
                              {acc.account_type === 'SAVINGS' && '💰 TÀI KHOẢN TIẾT KIỆM (SAVINGS)'}
                              {acc.account_type === 'CREDIT' && '📈 TÀI KHOẢN TÍN DỤNG (CREDIT)'}
                            </div>
                            <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)', marginTop: '4px' }}>
                              Số TK: <strong>{acc.account_number}</strong>
                            </div>
                          </div>
                          <div style={{ textAlign: 'right' }}>
                            <div style={{ fontWeight: 'bold', color: 'var(--secondary)' }}>
                              {acc.currency === 'VND' ? 
                                new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' }).format(acc.balance) :
                                new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(acc.balance)
                              }
                            </div>
                            <div style={{ fontSize: '0.75rem', color: acc.status === 'ACTIVE' ? 'var(--success)' : 'var(--error)', marginTop: '2px' }}>
                              Trạng thái: {acc.status}
                            </div>
                          </div>
                        </div>

                        {/* Action Buttons Row */}
                        <div style={{ display: 'flex', gap: '8px', justifyContent: 'flex-end', borderTop: '1px solid rgba(255,255,255,0.05)', paddingTop: '8px' }}>
                          <button
                            onClick={() => {
                              if (showDepositForm === acc.account_number) {
                                setShowDepositForm(null);
                              } else {
                                setShowDepositForm(acc.account_number);
                                setShowHistoryFor(null); // Close history if open
                              }
                            }}
                            className="btn"
                            style={{
                              width: 'auto',
                              padding: '4px 10px',
                              fontSize: '0.75rem',
                              borderRadius: '6px',
                              background: 'rgba(16, 185, 129, 0.15)',
                              color: 'var(--success)',
                              border: '1px solid rgba(16, 185, 129, 0.3)',
                              fontWeight: '600',
                              cursor: 'pointer'
                            }}
                          >
                            💵 Nạp tiền
                          </button>
                          <button
                            onClick={() => handleToggleHistory(acc.id, acc.account_number)}
                            className="btn"
                            style={{
                              width: 'auto',
                              padding: '4px 10px',
                              fontSize: '0.75rem',
                              borderRadius: '6px',
                              background: 'rgba(6, 182, 212, 0.15)',
                              color: 'var(--secondary)',
                              border: '1px solid rgba(6, 182, 212, 0.3)',
                              fontWeight: '600',
                              cursor: 'pointer'
                            }}
                          >
                            📜 Lịch sử
                          </button>
                        </div>

                        {/* Deposit Inline Form */}
                        {showDepositForm === acc.account_number && (
                          <div style={{
                            background: 'rgba(255,255,255,0.02)',
                            borderRadius: '8px',
                            padding: '12px',
                            border: '1px dashed var(--success)',
                            display: 'flex',
                            flexDirection: 'column',
                            gap: '8px',
                            marginTop: '4px'
                          }}>
                            <div style={{ fontSize: '0.85rem', fontWeight: 'bold', color: 'var(--success)' }}>
                              Nạp tiền vào tài khoản {acc.account_number}:
                            </div>
                            <div style={{ display: 'flex', gap: '8px' }}>
                              <input
                                type="number"
                                placeholder="Số tiền (VND)"
                                value={depositAmount}
                                onChange={(e) => setDepositAmount(e.target.value)}
                                style={{ flex: 1, padding: '6px 10px', fontSize: '0.85rem' }}
                                disabled={depositLoading}
                              />
                              <input
                                type="text"
                                placeholder="Nội dung nạp (tùy chọn)"
                                value={depositDescription}
                                onChange={(e) => setDepositDescription(e.target.value)}
                                style={{ flex: 2, padding: '6px 10px', fontSize: '0.85rem' }}
                                disabled={depositLoading}
                              />
                            </div>
                            <div style={{ display: 'flex', gap: '8px', justifyContent: 'flex-end' }}>
                              <button
                                onClick={() => setShowDepositForm(null)}
                                className="btn btn-secondary"
                                style={{ width: 'auto', padding: '4px 12px', fontSize: '0.8rem', borderRadius: '6px' }}
                                disabled={depositLoading}
                              >
                                Hủy
                              </button>
                              <button
                                onClick={() => handleDeposit(acc.account_number)}
                                className="btn btn-primary"
                                style={{ width: 'auto', padding: '4px 12px', fontSize: '0.8rem', borderRadius: '6px', background: 'var(--success)' }}
                                disabled={depositLoading}
                              >
                                {depositLoading ? 'Đang nạp...' : 'Xác nhận'}
                              </button>
                            </div>
                          </div>
                        )}

                        {/* Transactions History List */}
                        {showHistoryFor === acc.account_number && (
                          <div style={{
                            background: 'rgba(0,0,0,0.4)',
                            borderRadius: '8px',
                            padding: '12px',
                            border: '1px solid rgba(6, 182, 212, 0.2)',
                            marginTop: '4px',
                            maxHeight: '200px',
                            overflowY: 'auto'
                          }}>
                            <div style={{ fontSize: '0.85rem', fontWeight: 'bold', color: 'var(--secondary)', marginBottom: '8px' }}>
                              Lịch sử giao dịch ví {acc.account_number}:
                            </div>
                            {historyLoading ? (
                              <div style={{ textAlign: 'center', padding: '10px' }}>
                                <div className="spinner pulse-animation" style={{ width: '20px', height: '20px', margin: '0 auto' }} />
                              </div>
                            ) : accountTransactions.length === 0 ? (
                              <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)', textAlign: 'center', padding: '8px' }}>
                                Chưa có giao dịch nào phát sinh.
                              </div>
                            ) : (
                              <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                                {accountTransactions.map(tx => {
                                  const isReceived = tx.receiver_account_id === acc.id;
                                  const amtSign = isReceived ? '+' : '-';
                                  const amtColor = isReceived ? 'var(--success)' : 'var(--error)';
                                  return (
                                    <div key={tx.id} style={{
                                      display: 'flex',
                                      justifyContent: 'space-between',
                                      fontSize: '0.8rem',
                                      borderBottom: '1px solid rgba(255,255,255,0.03)',
                                      paddingBottom: '6px'
                                    }}>
                                      <div style={{ flex: 1, paddingRight: '10px' }}>
                                        <div style={{ fontWeight: '500', color: '#fff' }}>{tx.type} | <span style={{ color: 'var(--text-muted)' }}>{tx.reference_code}</span></div>
                                        <div style={{ fontSize: '0.75rem', color: 'var(--text-secondary)', marginTop: '2px' }}>
                                          {tx.description || 'Không có mô tả'}
                                        </div>
                                      </div>
                                      <div style={{ textAlign: 'right', fontWeight: 'bold', color: amtColor }}>
                                        {amtSign}{acc.currency === 'VND' ? 
                                          new Intl.NumberFormat('vi-VN', { style: 'decimal' }).format(tx.amount) :
                                          new Intl.NumberFormat('en-US', { style: 'decimal' }).format(tx.amount)
                                        } {acc.currency}
                                      </div>
                                    </div>
                                  );
                                })}
                              </div>
                            )}
                          </div>
                        )}
                      </div>
                    ))}
                  </div>
                )}
              </div>
            )}

            <div style={{ borderTop: '1px solid var(--glass-border)', paddingTop: '16px', marginBottom: '20px' }}>
              <h3 style={{ fontSize: '1.1rem', color: 'var(--text-secondary)', marginBottom: '12px' }}>Cấp ví tài khoản mới:</h3>
              
              <div style={{ display: 'flex', gap: '12px', alignItems: 'center', marginBottom: '16px' }}>
                <span style={{ fontSize: '0.85rem', color: 'var(--text-secondary)' }}>Chọn tiền tệ:</span>
                <select 
                  value={creationCurrency} 
                  onChange={(e) => setCreationCurrency(e.target.value)}
                  style={{
                    width: 'auto',
                    padding: '8px 12px',
                    background: 'rgba(0,0,0,0.3)',
                    border: '1px solid var(--glass-border)',
                    borderRadius: '8px',
                    color: '#fff',
                    fontSize: '0.85rem',
                    cursor: 'pointer'
                  }}
                  id="modal-currency-select"
                >
                  <option value="VND" style={{ background: '#0d0f1a' }}>VND</option>
                  <option value="USD" style={{ background: '#0d0f1a' }}>USD</option>
                </select>
              </div>

              <div style={{ display: 'flex', gap: '12px' }} id="modal-creation-actions">
                {!userAccounts.some(acc => acc.account_type === 'SAVINGS') && (
                  <button
                    id="modal-create-savings-btn"
                    onClick={() => handleCreateAccount(selectedUser.id, 'SAVINGS')}
                    className="btn btn-primary"
                    disabled={modalLoading}
                    style={{ flex: 1, padding: '10px 16px', fontSize: '0.85rem', borderRadius: '10px' }}
                  >
                    + Ví Tiết kiệm (SAVINGS)
                  </button>
                )}

                {!userAccounts.some(acc => acc.account_type === 'CREDIT') && (
                  <button
                    id="modal-create-credit-btn"
                    onClick={() => handleCreateAccount(selectedUser.id, 'CREDIT')}
                    className="btn btn-primary"
                    disabled={modalLoading}
                    style={{ flex: 1, padding: '10px 16px', fontSize: '0.85rem', borderRadius: '10px', background: 'linear-gradient(135deg, var(--accent) 0%, #c026d3 100%)' }}
                  >
                    + Ví Tín dụng (CREDIT)
                  </button>
                )}
                
                {userAccounts.some(acc => acc.account_type === 'SAVINGS') && userAccounts.some(acc => acc.account_type === 'CREDIT') && (
                  <p style={{ color: 'var(--text-muted)', fontSize: '0.85rem', fontStyle: 'italic' }}>
                    Khách hàng này đã được cấp đầy đủ các loại tài khoản (Payment, Savings, Credit).
                  </p>
                )}
              </div>
            </div>

            <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: '20px' }}>
              <button 
                id="modal-close-btn"
                onClick={() => { setShowAccountsModal(false); setSelectedUser(null); }} 
                className="btn btn-secondary" 
                style={{ width: 'auto', padding: '10px 20px', fontSize: '0.9rem', borderRadius: '10px' }}
              >
                Đóng
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Modal: Setup Popup for newly created child admin */}
      {createdAdminResult && (
        <div style={{
          position: 'fixed',
          top: 0, left: 0, right: 0, bottom: 0,
          background: 'rgba(5, 6, 11, 0.9)',
          backdropFilter: 'blur(10px)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          zIndex: 1100,
          padding: '20px'
        }} id="setup-modal-overlay">
          <div className="glass-container" style={{ maxWidth: '500px', border: '1.5px solid var(--accent)', boxShadow: '0 0 25px rgba(217, 70, 239, 0.3)' }}>
            <div style={{ textAlign: 'center', marginBottom: '20px' }}>
              <span style={{ fontSize: '3rem' }}>🔐</span>
              <h2 style={{ fontSize: '1.5rem', marginTop: '10px', color: '#fff' }}>Thông tin cấu hình Admin con</h2>
              <p style={{ fontSize: '0.85rem', color: 'var(--text-secondary)', marginTop: '4px' }}>
                Vui lòng chia sẻ các thông tin bảo mật này cho Quản trị viên mới.
              </p>
            </div>

            <div style={{
              background: 'rgba(0, 0, 0, 0.3)',
              borderRadius: '12px',
              padding: '16px',
              border: '1px solid var(--glass-border)',
              display: 'flex',
              flexDirection: 'column',
              gap: '12px',
              marginBottom: '24px'
            }}>
              <div>
                <span style={{ fontSize: '0.75rem', textTransform: 'uppercase', color: 'var(--text-muted)', fontWeight: 'bold' }}>Họ tên:</span>
                <div style={{ fontSize: '1rem', fontWeight: '500', marginTop: '2px' }}>{createdAdminResult.full_name}</div>
              </div>

              <div>
                <span style={{ fontSize: '0.75rem', textTransform: 'uppercase', color: 'var(--text-muted)', fontWeight: 'bold' }}>Tên đăng nhập (Email):</span>
                <div style={{ fontSize: '1rem', fontWeight: '500', marginTop: '2px' }}>{createdAdminResult.email}</div>
              </div>

              <div>
                <span style={{ fontSize: '0.75rem', textTransform: 'uppercase', color: 'var(--text-muted)', fontWeight: 'bold' }}>Số điện thoại:</span>
                <div style={{ fontSize: '1rem', fontWeight: '500', marginTop: '2px' }}>{createdAdminResult.phone}</div>
              </div>

              <div style={{ borderTop: '1px solid var(--glass-border)', paddingTop: '12px' }}>
                <span style={{ fontSize: '0.75rem', textTransform: 'uppercase', color: 'var(--accent)', fontWeight: 'bold' }}>Khóa bảo mật Google Authenticator (TOTP Secret Key):</span>
                <div style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: '8px',
                  marginTop: '4px'
                }}>
                  <code style={{
                    flex: 1,
                    background: 'rgba(255, 255, 255, 0.05)',
                    padding: '8px 12px',
                    borderRadius: '8px',
                    fontSize: '1.1rem',
                    fontWeight: 'bold',
                    color: 'var(--secondary)',
                    letterSpacing: '0.05em',
                    textAlign: 'center'
                  }}>
                    {createdAdminResult.totp_secret}
                  </code>
                  <button
                    onClick={() => copyToClipboard(createdAdminResult.totp_secret)}
                    className="btn btn-secondary"
                    style={{
                      width: 'auto',
                      padding: '8px 12px',
                      fontSize: '0.8rem',
                      borderRadius: '8px',
                      background: 'rgba(6, 182, 212, 0.15)',
                      color: 'var(--secondary)',
                      border: '1px solid rgba(6, 182, 212, 0.3)'
                    }}
                  >
                    {copiedSecret ? 'Đã sao chép!' : 'Sao chép'}
                  </button>
                </div>
                <p style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginTop: '8px', fontStyle: 'italic' }}>
                  * Nhập mã khóa này vào ứng dụng Authenticator để bắt đầu tạo mã đăng nhập 6 số.
                </p>
              </div>
            </div>

            <button
              onClick={() => setCreatedAdminResult(null)}
              className="btn btn-primary"
              style={{
                padding: '12px',
                borderRadius: '10px',
                fontWeight: 'bold',
                background: 'linear-gradient(135deg, var(--accent) 0%, #c026d3 100%)'
              }}
            >
              Đã sao lưu thông tin & Đóng lại
            </button>
          </div>
        </div>
      )}

    </>
  );
}
