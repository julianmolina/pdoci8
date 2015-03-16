
namespace Pdoci8;

/**
 *
 * @category Zephir OCI8
 * @package pdoci8
 * @author Julián Molina <b>jmolinac5116@ean.edu.co</b>
 */
class Pdoci extends \PDO
{

	/**
	 * Database handler
	 *
	 * @var resource
	 */
	public _dbh;

	/**
	 * Driver options
	 *
	 * @var array
	 */
	protected _options = [];

	/**
	 * Whether currently in a transaction
	 *
	 * @var bool
	 */
	protected _inTransaction = false;

	/**
	 * insert query statement table variable
	 *
	 * @var string
	 */
	protected _table;

	/**
	 * Creates a PDO instance representing a connection to a database
	 *
	 * @param $dsn
	 * @param $username [optional]
	 * @param $password [optional]
	 * @param array $options [optional]
	 * @throws Oci8Exception
	 */
	public function __construct(string dsn, var $username, var password, array options = [])
	{
		// Set default charset to AL32UTF8
		string charset = 'AL32UTF8';
		array error = [];
		// Get the character set
		if array_key_exists("charset", options) {
			let charset = options["charset"];
		}
		// Convert UTF8 charset to AL32UTF8
		let charset = strtolower(charset) == 'utf8' ? 'AL32UTF8' : charset;

		// Attempt a connection
		if isset options[PDO::ATTR_PERSISTENT] && options[PDO::ATTR_PERSISTENT]) {
			let this->_dbh = oci_pconnect(username, password, dsn, charset);
		} else {
			let this->_dbh = oci_connect(username, password, dsn, charset);
		}

		// Check if connection was successful
		if !this->_dbh {
			let error = oci_error();
			throw new PdociException(error);
		}

		let this->_options = options;
	}

	/**
	 *
	 */
	public function prepare(var stm, var opt = null)
	{

		array error = [];
		var parse = "";

		if opt == null {
			let opt = this->_options;
		}

		// Skip replacing ? with a pseudo named parameter on alter/create table command
		if !preg_match('/^alter+ +table/', strtolower(trim(stm)))
			  &
			 !preg_match('/^create+ +table/', strtolower(trim(stm))) {

			var newStatement = null;
			var index = 0;
			while newStatement !== stm {

				if newStatement !== null {
					let stm = newStatement;
				}
				let newStatement = preg_replace('/\?/', ':autoparam' . index, stm, 1);
				let index++;
			}
			let stm = newStatement;
		}

		if strpos(strtolower(stm), 'insert into') !== false {
			preg_match('/insert into\s+([^\s\(]*)?/', strtolower(stm), matches);
			// store insert into table name
			let this->_table = matches[1];
		}

		let parse = oci_parse(this->_dbh, stm);

		if !sth {
			let error = oci_error(this->_dbh);
			throw new PdociException(error);
		}

		if !is_array(options) {
			let options = [];
		}

		return new PdociStatement(sth, this, options);
	}

	/**
	 * Initiates a transaction
	 *
	 * @throws Oci8Exception
	 * @return bool TRUE on success or FALSE on failure
	 */
	public function beginTransaction()
	{
		if this->inTransaction() {
			throw new PdociException('There is already an active transaction');
		}

		this->_inTransaction = true;

		return true;
	}

	/**
	 * Returns true if the current process is in a transaction
	 *
	 * @deprecated Use inTransaction() instead
	 * @return bool
	 */
	public function isTransaction()
	{
		return this->_inTransaction;
	}

	/**
	 * Commits a transaction
	 *
	 * @throws Oci8Exception
	 * @return bool TRUE on success or FALSE on failure.
	 */
	public function commit()
	{
		if !this->inTransaction() {
			throw new PdociException('There is no active transaction');
		}

		if oci_commit(this->_dbh) {
			let this->_inTransaction = false;
			return true;
		}

		return false;
	}

	/**
	 * Rolls back a transaction
	 *
	 * @throws Oci8Exception
	 * @return bool TRUE on success or FALSE on failure.
	 */
	public function rollBack()
	{
		if !this->inTransaction() {
			throw new PdociException('There is no active transaction');
		}

		if oci_rollback(this->_dbh) {
			let this->_inTransaction = false;
			return true;
		}

		return false;
	}

	/**
	 * Sets an attribute on the database handle
	 *
	 * @param int $attribute
	 * @param mixed $value
	 * @return bool TRUE on success or FALSE on failure.
	 */
	public function setAttribute(var attr, var value)
	{
		let this->_options[attr] = value;
		return true;
	}

	/**
	 * Executes an SQL statement and returns the number of affected rows
	 *
	 * @param string $statement The SQL statement to prepare and execute.
	 * @return int The number of rows that were modified or deleted by the SQL
	 *   statement you issued.
	 */
	public function exec(statement)
	{
		var stmt = "";
		var stmt = this->prepare(statement);
		stmt->execute();

		return stmt->rowCount();
	}

	/**
	 *
	 */
	public function query(var statement, var fetchMode = null, var modeArg = null, array ctorArgs = [])
	{
		var stmt = "";
		let stmt = this->prepare(statement);
		stmt->execute();
		if fetchMode {
			stmt->setFetchMode(fetchMode, modeArg, ctorArgs);
		}

		return stmt;
	}

	/**
	 * returns the current value of the sequence related to the table where
	 * record is inserted. The sequence name should follow this for it to work
	 * properly:
	 *   {$table}.'_'.{$column}.'_seq'
	 * Oracle does not support the last inserted ID functionality like MySQL.
	 * If the above sequence does not exist, the method will return 0;
	 *
	 * @param string $name Sequence name; no use in this context
	 * @return mixed Last sequence number or 0 if sequence does not exist
	 */
	public function lastInsertId(var name = null)
	{

		var stmt = "";
		var id = 0;
		var sequence = "";

		let sequence = this->_table . "_" . name . "_seq";
		if !this->checkSequence($sequence) {
			return 0;
		}

		let stmt = this->query("select {$sequence}.currval from dual", \PDO::FETCH_COLUMN);
		let id = stmt->fetch();

		return id;
	}

	/**
	 * Fetch the SQLSTATE associated with the last operation on the database
	 * handle
	 * While this returns an error code, it merely emulates the action. If
	 * there are no errors, it returns the success SQLSTATE code (00000).
	 * If there are errors, it returns HY000. See errorInfo() to retrieve
	 * the actual Oracle error code and message.
	 *
	 * @return string
	 */
	public function errorCode()
	{
		var error = "";
		let error = this->errorInfo();
		return error[0];
	}

	/**
	 * Returns extended error information for the last operation on the database
	 * handle
	 * The array consists of the following fields:
	 *   0  SQLSTATE error code (a five characters alphanumeric identifier
	 *      defined in the ANSI SQL standard).
	 *   1  Driver-specific error code.
	 *   2  Driver-specific error message.
	 *
	 * @return array Error information
	 */
	public function errorInfo()
	{
		array error = [];
		let error = oci_error(this->_dbh);

		if is_array(error) {
			return [
				'HY000',
				error['code'],
				error['message']
			];
		}

		return ['00000', null, null];
	}

	/**
	 * Retrieve a database connection attribute
	 *
	 * @param int $attribute
	 * @return mixed A successful call returns the value of the requested PDO
	 *   attribute. An unsuccessful call returns null.
	 */
	public function getAttribute(attr)
	{
		if attr == \PDO::ATTR_DRIVER_NAME {
			return "oci8";
		}

		if isset this->_options[attr] {
			return this->_options[attr];
		}

		return null;
	}

	/**
	 * Special non PDO function used to start cursors in the database
	 * Remember to call oci_free_statement() on your cursor
	 *
	 * @access public
	 * @return mixed New statement handle, or FALSE on error.
	 */
	public function getNewCursor()
	{
		return oci_new_cursor(this->_dbh);
	}

	/**
	 * Special non PDO function used to start descriptor in the database
	 * Remember to call oci_free_statement() on your cursor
	 *
	 * @access public
	 * @param int $type One of OCI_DTYPE_FILE, OCI_DTYPE_LOB or OCI_DTYPE_ROWID.
	 * @return mixed New LOB or FILE descriptor on success, FALSE on error.
	 */
	public function getNewDescriptor(var type = OCI_D_LOB)
	{
		return oci_new_descriptor(this->_dbh, type);
	}

	/**
	 * Special non PDO function used to close an open cursor in the database
	 *
	 * @access public
	 * @param mixed $cursor A valid OCI statement identifier.
	 * @return mixed Returns TRUE on success or FALSE on failure.
	 */
	public function closeCursor(cursor)
	{
		return oci_free_statement(cursor);
	}

	/**
	 * Places quotes around the input string
	 *  If you are using this function to build SQL statements, you are strongly
	 * recommended to use prepare() to prepare SQL statements with bound
	 * parameters instead of using quote() to interpolate user input into an SQL
	 * statement. Prepared statements with bound parameters are not only more
	 * portable, more convenient, immune to SQL injection, but are often much
	 * faster to execute than interpolated queries, as both the server and
	 * client side can cache a compiled form of the query.
	 *
	 * @param string $string The string to be quoted.
	 * @param int $paramType Provides a data type hint for drivers that have
	 *   alternate quoting styles
	 * @return string Returns a quoted string that is theoretically safe to pass
	 *   into an SQL statement.
	 * @todo Implement support for $paramType.
	 */
	public function quote(string str, int paramType = \PDO::PARAM_STR)
	{
		return "'" . str_replace("'", "''", str) . "'";
	}

	/**
	 * Special non PDO function to check if sequence exists
	 *
	 * @param  string $name
	 * @return boolean
	 */
	public function checkSequence(name)
	{

		var stmt = "";
		if !name {
			return false;
		}

		let stmt = this->query("SELECT
													count(*)
            					  FROM
													all_sequences
            						WHERE
                					sequence_name=upper('". name ."') AND
                					sequence_owner=upper(user)",
												\PDO::FETCH_COLUMN);

		return stmt->fetch();
	}

}
